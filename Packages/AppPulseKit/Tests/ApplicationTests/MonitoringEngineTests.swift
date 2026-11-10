import Domain
import Testing
@testable import Application

struct MonitoringEngineTests {
    private let chrome = AppIdentity(id: "/Applications/Chrome.app", name: "Chrome", bundleIdentifier: "com.example.chrome")

    private let processes = Box<Result<[ProcessSample], SampleError>>(.success([]))
    private let gpu = Box<Result<GPUSample, SampleError>>(.success(GPUSample(nanosecondsByPID: [:], deviceBusyFraction: nil)))
    private let network = Box<Result<[NetworkSample], SampleError>>(.success([]))
    private let system = Box(SystemSample(
        logicalCores: 2,
        physicalMemoryBytes: 1000,
        memoryUsedBytes: nil,
        cpuBusyTicks: nil,
        cpuTotalTicks: nil
    ))

    private func makeEngine(
        hostNames: [String: String] = [:],
        signers: [String: CodeSigner] = [:],
        foreground: Set<String> = ["com.example.chrome"]
    ) -> MonitoringEngine {
        MonitoringEngine(providers: .init(
            processes: FakeProcesses(result: processes),
            gpu: FakeGPU(result: gpu),
            network: FakeNetwork(result: network),
            system: FakeSystem(value: system),
            owners: FakeOwners(apps: [10: chrome]),
            hostNames: FakeHostNames(names: hostNames),
            signatures: FakeSignatures(signers: signers),
            foregroundApps: FakeForegroundApps(identifiers: foreground)
        ))
    }

    @Test func backgroundListsOnlyProgramsWithoutAWindow() async {
        let engine = makeEngine()
        processes.value = .success([
            ProcessSample(pid: 10, cpuNanoseconds: 0, memoryBytes: 100),
            ProcessSample(pid: 20, cpuNanoseconds: 0, memoryBytes: 200),
        ])
        _ = await engine.tick(now: 0)
        let snapshot = await engine.tick(now: 2)

        #expect(snapshot?.backgroundPrograms.map(\.path) == ["/bin/process-20"])
        #expect(snapshot?.backgroundPrograms.first?.memoryBytes == 200)
    }

    @Test func backgroundIncludesProcessesThatCantBeRead() async {
        let engine = makeEngine()
        processes.value = .success([
            ProcessSample(pid: 10, cpuNanoseconds: 0, memoryBytes: 100),
            ProcessSample(pid: 30, cpuNanoseconds: nil, memoryBytes: nil),
        ])
        _ = await engine.tick(now: 0)
        let snapshot = await engine.tick(now: 2)

        let program = snapshot?.backgroundPrograms.first { $0.path == "/bin/process-30" }
        #expect(program != nil)
        #expect(program?.isReadable == false)
    }

    @Test func signersArriveOnceChecked() async {
        let engine = makeEngine(signers: ["/bin/process-20": .unsigned])
        processes.value = .success([
            ProcessSample(pid: 10, cpuNanoseconds: 0, memoryBytes: 100),
            ProcessSample(pid: 20, cpuNanoseconds: 0, memoryBytes: 200),
        ])
        _ = await engine.tick(now: 0)

        var signer: CodeSigner?
        for step in 1...50 where signer == nil {
            let snapshot = await engine.tick(now: Double(step))
            signer = snapshot?.backgroundPrograms.first?.signer
            await Task.yield()
        }
        #expect(signer == .unsigned)
    }

    private func app(_ snapshot: UsageSnapshot?, _ id: String) -> AppUsage? {
        snapshot?.apps.first { $0.id == id }
    }

    @Test func firstTickOnlySetsTheBaseline() async {
        #expect(await makeEngine().tick(now: 0) == nil)
    }

    @Test func cpuIsAShareOfAllCores() async {
        let engine = makeEngine()
        processes.value = .success([ProcessSample(pid: 10, cpuNanoseconds: 0, memoryBytes: 100)])
        _ = await engine.tick(now: 0)
        // One full core for 2 seconds on a 2-core machine is 50% of the machine.
        processes.value = .success([ProcessSample(pid: 10, cpuNanoseconds: 2_000_000_000, memoryBytes: 100)])
        let snapshot = await engine.tick(now: 2)

        #expect(app(snapshot, chrome.id)?.cpuFraction == 0.5)
        #expect(app(snapshot, chrome.id)?.memoryBytes == 100)
    }

    @Test func gpuAndNetworkRatesUseTheirCounters() async {
        let engine = makeEngine()
        gpu.value = .success(GPUSample(nanosecondsByPID: [10: 0], deviceBusyFraction: 0.5))
        network.value = .success([NetworkSample(pid: 10, bytesIn: 0, bytesOut: 0, connections: [])])
        _ = await engine.tick(now: 0)
        gpu.value = .success(GPUSample(nanosecondsByPID: [10: 500_000_000], deviceBusyFraction: 0.5))
        network.value = .success([NetworkSample(pid: 10, bytesIn: 2000, bytesOut: 400, connections: [])])
        let snapshot = await engine.tick(now: 2)

        #expect(app(snapshot, chrome.id)?.gpuFraction == 0.25)
        #expect(app(snapshot, chrome.id)?.downloadBytesPerSecond == 1000)
        #expect(app(snapshot, chrome.id)?.uploadBytesPerSecond == 200)
        #expect(app(snapshot, AppIdentity.system.id)?.gpuFraction == 0.25)
    }

    @Test func oneFailingMetricLeavesTheOthersWorking() async {
        let engine = makeEngine()
        processes.value = .success([ProcessSample(pid: 10, cpuNanoseconds: 0, memoryBytes: 100)])
        _ = await engine.tick(now: 0)
        gpu.value = .failure(SampleError())
        network.value = .failure(SampleError())
        processes.value = .success([ProcessSample(pid: 10, cpuNanoseconds: 2_000_000_000, memoryBytes: 100)])
        let snapshot = await engine.tick(now: 2)

        #expect(snapshot?.gpuStatus == .unavailable)
        #expect(snapshot?.networkStatus == .unavailable)
        #expect(snapshot?.processStatus == .available)
        #expect(app(snapshot, chrome.id)?.cpuFraction == 0.5)
    }

    @Test func recoveryAfterFailureDoesNotReportAFalseSpike() async {
        let engine = makeEngine()
        network.value = .success([NetworkSample(pid: 10, bytesIn: 0, bytesOut: 0, connections: [])])
        _ = await engine.tick(now: 0)
        network.value = .failure(SampleError())
        _ = await engine.tick(now: 2)
        network.value = .success([NetworkSample(pid: 10, bytesIn: 1_000_000, bytesOut: 0, connections: [])])
        let snapshot = await engine.tick(now: 4)

        #expect(snapshot?.networkStatus == .available)
        #expect(app(snapshot, chrome.id)?.downloadBytesPerSecond == 0)
    }

    @Test func onlyExternalHostsAreRecorded() async {
        let engine = makeEngine()
        _ = await engine.tick(now: 0)
        network.value = .success([NetworkSample(pid: 10, bytesIn: 0, bytesOut: 0, connections: [
            NetworkConnection(remoteAddress: "203.0.113.5", remotePort: 443),
            NetworkConnection(remoteAddress: "192.168.1.1", remotePort: 80),
        ])])
        let snapshot = await engine.tick(now: 2)

        #expect(app(snapshot, chrome.id)?.destinations.map(\.address) == ["203.0.113.5"])
        #expect(app(snapshot, chrome.id)?.destinations.first?.isActive == true)
    }

    @Test func closedConnectionStaysInHistoryAsInactive() async {
        let engine = makeEngine()
        _ = await engine.tick(now: 0)
        network.value = .success([NetworkSample(pid: 10, bytesIn: 0, bytesOut: 0, connections: [
            NetworkConnection(remoteAddress: "203.0.113.5", remotePort: 443),
        ])])
        _ = await engine.tick(now: 2)
        network.value = .success([NetworkSample(pid: 10, bytesIn: 0, bytesOut: 0, connections: [])])
        let snapshot = await engine.tick(now: 4)

        #expect(app(snapshot, chrome.id)?.destinations.first?.isActive == false)
    }

    @Test func hostNamesAppearOnceResolved() async {
        let engine = makeEngine(hostNames: ["203.0.113.5": "example.net"])
        _ = await engine.tick(now: 0)
        network.value = .success([NetworkSample(pid: 10, bytesIn: 0, bytesOut: 0, connections: [
            NetworkConnection(remoteAddress: "203.0.113.5", remotePort: 443),
        ])])

        var name: String?
        for step in 1...50 where name == nil {
            let snapshot = await engine.tick(now: Double(step))
            name = app(snapshot, chrome.id)?.destinations.first?.hostName
            await Task.yield()
        }
        #expect(name == "example.net")
    }

    @Test func pauseStartsRatesFresh() async {
        let engine = makeEngine()
        processes.value = .success([ProcessSample(pid: 10, cpuNanoseconds: 0, memoryBytes: 100)])
        _ = await engine.tick(now: 0)
        await engine.pause()
        processes.value = .success([ProcessSample(pid: 10, cpuNanoseconds: 9_000_000_000, memoryBytes: 100)])
        #expect(await engine.tick(now: 100) == nil)
    }
}
