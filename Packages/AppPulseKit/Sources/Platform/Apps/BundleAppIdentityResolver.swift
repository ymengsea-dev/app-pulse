import Darwin
import Domain
import Foundation
import Synchronization

/// Finds the app that owns a process from its path, or from the process macOS holds responsible for it.
public final class BundleAppIdentityResolver: AppIdentityResolving {
    private let cache = Mutex<[String: AppIdentity]>([:])

    public init() {}

    public func owner(ofPID pid: Int32) -> ProcessOwner {
        guard let path = Self.executablePath(of: pid) else {
            return ProcessOwner(app: .system, processName: "Process \(pid)")
        }
        let processName = (path as NSString).lastPathComponent

        if let app = appIdentity(forPath: path) {
            return ProcessOwner(app: app, processName: processName, executablePath: path)
        }
        // Covers tools started from a terminal, and framework helpers such as WebKit's.
        if let responsible = Self.responsiblePID(of: pid), responsible != pid,
           let responsiblePath = Self.executablePath(of: responsible),
           let app = appIdentity(forPath: responsiblePath) {
            return ProcessOwner(app: app, processName: processName, executablePath: path)
        }
        return ProcessOwner(app: .system, processName: processName, executablePath: path)
    }

    private func appIdentity(forPath path: String) -> AppIdentity? {
        guard let bundlePath = AppPathClassifier.outermostAppBundle(in: path),
              !AppPathClassifier.isSystemBundle(bundlePath) else { return nil }
        return cache.withLock { cache in
            if let cached = cache[bundlePath] { return cached }
            let identity = Self.makeIdentity(bundlePath: bundlePath)
            cache[bundlePath] = identity
            return identity
        }
    }

    private static func makeIdentity(bundlePath: String) -> AppIdentity {
        let bundle = Bundle(path: bundlePath)
        let fileName = ((bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
        // Not the bundle's own names: VS Code calls itself "Code". The file name is what people see in Applications.
        return AppIdentity(
            id: bundlePath,
            name: fileName,
            bundlePath: bundlePath,
            bundleIdentifier: bundle?.bundleIdentifier
        )
    }

    private static func executablePath(of pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private typealias ResponsibilityFunction = @convention(c) (pid_t) -> pid_t

    /// A private symbol, looked up at runtime so that its removal cannot stop the app launching.
    private static let responsibilityFunction: ResponsibilityFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else {
            return nil
        }
        return unsafeBitCast(symbol, to: ResponsibilityFunction.self)
    }()

    private static func responsiblePID(of pid: Int32) -> Int32? {
        guard let result = responsibilityFunction?(pid), result > 0 else { return nil }
        return result
    }
}
