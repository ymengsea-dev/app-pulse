import Synchronization
@testable import AppPulse

struct SampleError: Error {}

/// A value tests can change between ticks, from any task.
final class Box<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>
    init(_ value: Value) { storage = Mutex(value) }
    var value: Value {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}

struct FakeProcesses: ProcessMetricsProviding {
    let result: Box<Result<[ProcessSample], SampleError>>
    func sample() throws -> [ProcessSample] { try result.value.get() }
}

struct FakeGPU: GPUMetricsProviding {
    let result: Box<Result<GPUSample, SampleError>>
    func sample() throws -> GPUSample { try result.value.get() }
}

struct FakeNetwork: NetworkMetricsProviding {
    let result: Box<Result<[NetworkSample], SampleError>>
    func sample() throws -> [NetworkSample] { try result.value.get() }
}

struct FakeSystem: SystemMetricsProviding {
    let value: Box<SystemSample>
    func sample() -> SystemSample { value.value }
}

struct FakeOwners: AppIdentityResolving {
    let apps: [Int32: AppIdentity]
    func owner(ofPID pid: Int32) -> ProcessOwner {
        ProcessOwner(app: apps[pid] ?? .system, processName: "process-\(pid)", executablePath: "/bin/process-\(pid)")
    }
}

struct FakeSignatures: CodeSignatureChecking {
    let signers: [String: CodeSigner]
    func signer(forPath path: String) -> CodeSigner { signers[path] ?? .unknown }
}

struct FakeForegroundApps: ForegroundAppsProviding {
    let identifiers: Set<String>
    func foregroundBundleIdentifiers() -> Set<String> { identifiers }
}

struct FakeHostNames: HostNameResolving {
    let names: [String: String]
    func hostName(forAddress address: String) -> String? { names[address] }
}

@MainActor
final class FakeTerminator: AppTerminating {
    var running: Set<String>
    var closesOnQuit = true
    var closesOnForceQuit = true
    private(set) var quitRequests: [String] = []
    private(set) var forceQuitRequests: [String] = []

    init(running: Set<String>) { self.running = running }

    func canTerminate(bundleIdentifier: String) -> Bool { running.contains(bundleIdentifier) }
    func isRunning(bundleIdentifier: String) -> Bool { running.contains(bundleIdentifier) }

    func requestQuit(bundleIdentifier: String) {
        quitRequests.append(bundleIdentifier)
        if closesOnQuit { running.remove(bundleIdentifier) }
    }

    func forceQuit(bundleIdentifier: String) {
        forceQuitRequests.append(bundleIdentifier)
        if closesOnForceQuit { running.remove(bundleIdentifier) }
    }
}
