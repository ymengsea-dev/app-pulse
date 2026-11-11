/// The app a process belongs to, as the user would name it.
public struct AppIdentity: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let bundlePath: String?
    public let bundleIdentifier: String?

    public init(id: String, name: String, bundlePath: String? = nil, bundleIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.bundlePath = bundlePath
        self.bundleIdentifier = bundleIdentifier
    }

    /// Everything that cannot be tied to an app.
    public static let system = AppIdentity(id: "system", name: "macOS & other")

    public var isSystem: Bool { id == Self.system.id }
}

/// Who owns a process, and what the process itself is called.
public struct ProcessOwner: Hashable, Sendable {
    public let app: AppIdentity
    public let processName: String
    /// The program file. Nil when macOS won't say, as for the kernel.
    public let executablePath: String?

    public init(app: AppIdentity, processName: String, executablePath: String? = nil) {
        self.app = app
        self.processName = processName
        self.executablePath = executablePath
    }
}
