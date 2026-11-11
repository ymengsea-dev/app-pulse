import AppKit

/// Apps with a window or Dock icon, as opposed to menu bar extras and background helpers.
@MainActor
public struct WorkspaceForegroundApps: ForegroundAppsProviding {
    public init() {}

    public func foregroundBundleIdentifiers() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier))
    }
}
