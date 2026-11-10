/// Reads CPU time and memory for every readable process.
public protocol ProcessMetricsProviding: Sendable {
    func sample() async throws -> [ProcessSample]
}

/// Reads per-process GPU time and overall GPU load.
public protocol GPUMetricsProviding: Sendable {
    func sample() async throws -> GPUSample
}

/// Reads per-process traffic and open connections.
public protocol NetworkMetricsProviding: Sendable {
    func sample() async throws -> [NetworkSample]
}

/// Reads whole-machine CPU and memory figures.
public protocol SystemMetricsProviding: Sendable {
    func sample() async -> SystemSample
}

/// Works out which app owns a process.
public protocol AppIdentityResolving: Sendable {
    func owner(ofPID pid: Int32) -> ProcessOwner
}

/// Looks up the network name of an address. Returns nil when it has none.
public protocol HostNameResolving: Sendable {
    func hostName(forAddress address: String) async -> String?
}

/// Checks who signed a program. Slow, so implementations cache their answers.
public protocol CodeSignatureChecking: Sendable {
    func signer(forPath path: String) async -> CodeSigner
}

/// Lists the apps that have a window or Dock icon.
@MainActor
public protocol ForegroundAppsProviding: Sendable {
    func foregroundBundleIdentifiers() -> Set<String>
}

/// Closes running apps.
@MainActor
public protocol AppTerminating: Sendable {
    func canTerminate(bundleIdentifier: String) -> Bool
    func isRunning(bundleIdentifier: String) -> Bool
    func requestQuit(bundleIdentifier: String)
    func forceQuit(bundleIdentifier: String)
}
