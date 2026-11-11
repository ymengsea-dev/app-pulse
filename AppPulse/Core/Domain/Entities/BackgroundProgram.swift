/// Who signed a program, as macOS reports it.
public enum CodeSigner: Hashable, Sendable {
    case apple
    /// Signed by a developer Apple has identified, such as "Google LLC".
    case developer(String)
    /// Signed without a developer identity, as locally built tools are.
    case adHoc
    case unsigned
    /// Signed, but the file no longer matches its signature.
    case invalid
    /// macOS could not check it, for example because the file is gone.
    case unknown

    /// No identified developer stands behind it. A reason to look closer, not proof of harm.
    public var isUnverified: Bool {
        switch self {
        case .adHoc, .unsigned, .invalid: true
        case .apple, .developer, .unknown: false
        }
    }
}

/// A program running with no window or Dock icon, with all of its processes combined.
public struct BackgroundProgram: Equatable, Sendable, Identifiable {
    public let path: String
    public let name: String
    /// The app bundle it lives in, if any, for its icon.
    public let bundlePath: String?
    public var processCount: Int
    public var cpuFraction: Double
    public var memoryBytes: UInt64
    public var networkBytesPerSecond: Double
    /// False when every process belongs to another user, such as root, so its figures can't be read.
    public var isReadable: Bool
    /// Nil while its signature is still being checked.
    public var signer: CodeSigner?

    public var id: String { path }

    public init(
        path: String,
        name: String,
        bundlePath: String? = nil,
        processCount: Int = 0,
        cpuFraction: Double = 0,
        memoryBytes: UInt64 = 0,
        networkBytesPerSecond: Double = 0,
        isReadable: Bool = false,
        signer: CodeSigner? = nil
    ) {
        self.path = path
        self.name = name
        self.bundlePath = bundlePath
        self.processCount = processCount
        self.cpuFraction = cpuFraction
        self.memoryBytes = memoryBytes
        self.networkBytesPerSecond = networkBytesPerSecond
        self.isReadable = isReadable
        self.signer = signer
    }
}
