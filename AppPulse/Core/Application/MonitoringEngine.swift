import Foundation

/// Samples every metric on a timer and publishes one snapshot per sample.
/// A metric that fails is marked unavailable. The others carry on.
public actor MonitoringEngine {
    public struct Providers: Sendable {
        let processes: any ProcessMetricsProviding
        let gpu: any GPUMetricsProviding
        let network: any NetworkMetricsProviding
        let system: any SystemMetricsProviding
        let owners: any AppIdentityResolving
        let hostNames: any HostNameResolving
        let signatures: any CodeSignatureChecking
        let foregroundApps: any ForegroundAppsProviding

        public init(
            processes: any ProcessMetricsProviding,
            gpu: any GPUMetricsProviding,
            network: any NetworkMetricsProviding,
            system: any SystemMetricsProviding,
            owners: any AppIdentityResolving,
            hostNames: any HostNameResolving,
            signatures: any CodeSignatureChecking,
            foregroundApps: any ForegroundAppsProviding
        ) {
            self.processes = processes
            self.gpu = gpu
            self.network = network
            self.system = system
            self.owners = owners
            self.hostNames = hostNames
            self.signatures = signatures
            self.foregroundApps = foregroundApps
        }
    }

    private let providers: Providers
    private let interval: Duration
    private var loop: Task<Void, Never>?

    private var lastTick: TimeInterval?
    private var cpuRates = RateCalculator<Int32>()
    private var gpuRates = RateCalculator<Int32>()
    private var downloadRates = RateCalculator<Int32>()
    private var uploadRates = RateCalculator<Int32>()
    private var systemCPURates = RateCalculator<String>()

    private var history = DestinationHistory()
    private var requestedLookups: Set<String> = []
    private var pendingLookups: [String] = []
    private var lookupTask: Task<Void, Never>?

    private var signers: [String: CodeSigner] = [:]
    private var requestedSignatureChecks: Set<String> = []
    private var pendingSignatureChecks: [String] = []
    private var signatureTask: Task<Void, Never>?

    public init(providers: Providers, interval: Duration = .seconds(2)) {
        self.providers = providers
        self.interval = interval
    }

    /// Starts sampling. The first snapshot arrives after a short baseline reading.
    public func start(onSnapshot: @escaping @Sendable (UsageSnapshot) async -> Void) {
        guard loop == nil else { return }
        loop = Task { [interval] in
            while !Task.isCancelled {
                let snapshot = await tick(now: ProcessInfo.processInfo.systemUptime)
                if let snapshot {
                    await onSnapshot(snapshot)
                    try? await Task.sleep(for: interval)
                } else {
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        }
    }

    /// Stops sampling. Rates start fresh on the next start, so idle time is never averaged in.
    public func pause() async {
        loop?.cancel()
        await loop?.value
        loop = nil
        lastTick = nil
        cpuRates.reset()
        gpuRates.reset()
        downloadRates.reset()
        uploadRates.reset()
        systemCPURates.reset()
    }

    /// Takes one reading. Returns nil on the first reading, which only sets the baseline.
    func tick(now: TimeInterval) async -> UsageSnapshot? {
        let providers = self.providers
        async let processResult = capture { try await providers.processes.sample() }
        async let gpuResult = capture { try await providers.gpu.sample() }
        async let networkResult = capture { try await providers.network.sample() }
        async let systemSample = providers.system.sample()

        let (processes, gpu, network, system) = await (processResult, gpuResult, networkResult, systemSample)

        let elapsed = lastTick.map { now - $0 } ?? 0
        let isBaseline = lastTick == nil
        lastTick = now

        let cpu = cpuRateByPID(processes, elapsed: elapsed, cores: system.logicalCores)
        let gpuFractions = gpuFractionByPID(gpu, elapsed: elapsed)
        let (download, upload) = networkRatesByPID(network, elapsed: elapsed)
        let cpuBusy = systemCPUBusy(system, elapsed: elapsed)

        guard !isBaseline else { return nil }

        let samples = (try? processes.get()) ?? []
        let networkSamples = (try? network.get()) ?? []
        let memory = Dictionary(samples.map { ($0.pid, $0.memoryBytes ?? 0) }, uniquingKeysWith: { first, _ in first })
        let unreadable = Set(samples.filter { !$0.isReadable }.map(\.pid))

        let pids = Set(samples.map(\.pid)).union(cpu.keys).union(gpuFractions.keys).union(download.keys)
        let owners = Dictionary(uniqueKeysWithValues: pids.map { ($0, providers.owners.owner(ofPID: $0)) })

        let usages = pids.compactMap { pid -> ProcessUsage? in
            guard let owner = owners[pid] else { return nil }
            return ProcessUsage(
                pid: pid,
                owner: owner,
                cpuFraction: cpu[pid] ?? 0,
                memoryBytes: memory[pid] ?? 0,
                gpuFraction: gpuFractions[pid] ?? 0,
                downloadBytesPerSecond: download[pid] ?? 0,
                uploadBytesPerSecond: upload[pid] ?? 0,
                isReadable: !unreadable.contains(pid)
            )
        }

        let foreground = await providers.foregroundApps.foregroundBundleIdentifiers()
        let background = BackgroundProgramBuilder.build(usages, foregroundBundleIdentifiers: foreground, signers: signers)
        queueSignatureChecks(Set(background.map(\.path)))

        var addressesByApp: [String: Set<String>] = [:]
        for sample in networkSamples {
            let external = sample.connections.map(\.remoteAddress).filter(ExternalAddressFilter.isExternal)
            guard !external.isEmpty, let owner = owners[sample.pid] else { continue }
            addressesByApp[owner.app.id, default: []].formUnion(external)
        }
        history.update(addressesByApp: addressesByApp, at: Date())
        queueLookups(addressesByApp.values.reduce(into: Set<String>()) { $0.formUnion($1) })

        let load = SystemLoad(
            cpuBusyFraction: cpuBusy,
            gpuBusyFraction: (try? gpu.get())?.deviceBusyFraction,
            memoryUsedBytes: system.memoryUsedBytes,
            physicalMemoryBytes: system.physicalMemoryBytes
        )
        let apps = UsageAggregator.aggregate(usages, load: load).map { app in
            var app = app
            app.destinations = history.destinations(forApp: app.id)
            return app
        }

        return UsageSnapshot(
            apps: apps,
            load: load,
            processStatus: status(of: processes),
            gpuStatus: status(of: gpu),
            networkStatus: status(of: network),
            backgroundPrograms: background
        )
    }

    private func cpuRateByPID(
        _ result: Result<[ProcessSample], any Error>,
        elapsed: TimeInterval,
        cores: Int
    ) -> [Int32: Double] {
        guard case .success(let samples) = result else {
            // Without this, the next good reading would count the failed interval's time as one interval's work.
            cpuRates.reset()
            return [:]
        }
        let counters = Dictionary(
            samples.compactMap { sample in sample.cpuNanoseconds.map { (sample.pid, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        let capacity = 1_000_000_000 * Double(max(cores, 1))
        return cpuRates.rates(counters: counters, elapsedSeconds: elapsed).mapValues { $0 / capacity }
    }

    private func gpuFractionByPID(_ result: Result<GPUSample, any Error>, elapsed: TimeInterval) -> [Int32: Double] {
        guard case .success(let sample) = result else {
            gpuRates.reset()
            return [:]
        }
        return gpuRates.rates(counters: sample.nanosecondsByPID, elapsedSeconds: elapsed)
            .mapValues { $0 / 1_000_000_000 }
    }

    private func networkRatesByPID(
        _ result: Result<[NetworkSample], any Error>,
        elapsed: TimeInterval
    ) -> (download: [Int32: Double], upload: [Int32: Double]) {
        guard case .success(let samples) = result else {
            downloadRates.reset()
            uploadRates.reset()
            return ([:], [:])
        }
        let down = Dictionary(samples.map { ($0.pid, $0.bytesIn) }, uniquingKeysWith: { first, _ in first })
        let up = Dictionary(samples.map { ($0.pid, $0.bytesOut) }, uniquingKeysWith: { first, _ in first })
        return (
            downloadRates.rates(counters: down, elapsedSeconds: elapsed),
            uploadRates.rates(counters: up, elapsedSeconds: elapsed)
        )
    }

    private func systemCPUBusy(_ system: SystemSample, elapsed: TimeInterval) -> Double? {
        guard let busy = system.cpuBusyTicks, let total = system.cpuTotalTicks else {
            systemCPURates.reset()
            return nil
        }
        let rates = systemCPURates.rates(counters: ["busy": busy, "total": total], elapsedSeconds: elapsed)
        guard let totalRate = rates["total"], totalRate > 0, let busyRate = rates["busy"] else { return nil }
        return busyRate / totalRate
    }

    private func status<T>(of result: Result<T, any Error>) -> MetricStatus {
        if case .success = result { return .available }
        return .unavailable
    }

    private func queueLookups(_ addresses: Set<String>) {
        let new = addresses.subtracting(requestedLookups)
        guard !new.isEmpty else { return }
        requestedLookups.formUnion(new)
        pendingLookups.append(contentsOf: new)
        guard lookupTask == nil else { return }
        lookupTask = Task { await drainLookups() }
    }

    /// One at a time, so a slow DNS server cannot pile up blocked threads.
    private func drainLookups() async {
        while let address = pendingLookups.popLast() {
            if let name = await providers.hostNames.hostName(forAddress: address) {
                history.setHostName(name, forAddress: address)
            }
        }
        lookupTask = nil
    }

    private func queueSignatureChecks(_ paths: Set<String>) {
        let new = paths.subtracting(requestedSignatureChecks)
        guard !new.isEmpty else { return }
        requestedSignatureChecks.formUnion(new)
        pendingSignatureChecks.append(contentsOf: new.sorted())
        guard signatureTask == nil else { return }
        signatureTask = Task { await drainSignatureChecks() }
    }

    /// One file at a time, so checking hundreds of programs never competes with sampling.
    private func drainSignatureChecks() async {
        while !pendingSignatureChecks.isEmpty {
            let path = pendingSignatureChecks.removeFirst()
            signers[path] = await providers.signatures.signer(forPath: path)
        }
        signatureTask = nil
    }
}

private func capture<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> Result<T, any Error> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}
