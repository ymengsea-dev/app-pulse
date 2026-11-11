import AppKit

/// Closes apps through `NSRunningApplication`.
@MainActor
public struct WorkspaceAppTerminator: AppTerminating {
    public init() {}

    public func canTerminate(bundleIdentifier: String) -> Bool {
        bundleIdentifier != Bundle.main.bundleIdentifier && isRunning(bundleIdentifier: bundleIdentifier)
    }

    public func isRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    public func requestQuit(bundleIdentifier: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
            app.terminate()
        }
    }

    public func forceQuit(bundleIdentifier: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
            app.forceTerminate()
        }
    }
}
