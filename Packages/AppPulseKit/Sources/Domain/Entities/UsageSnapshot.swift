import Foundation

/// An external host an app has talked to during this session.
public struct Destination: Equatable, Sendable, Identifiable {
    public let address: String
    public var hostName: String?
    public var isActive: Bool
    public var lastSeen: Date

    public var id: String { address }

    public init(address: String, hostName: String? = nil, isActive: Bool, lastSeen: Date) {
        self.address = address
        self.hostName = hostName
        self.isActive = isActive
        self.lastSeen = lastSeen
    }
}

/// A process's current rates, after deltas are applied.
public struct ProcessUsage: Equatable, Sendable {
    public let pid: Int32
    public let owner: ProcessOwner
    public let cpuFraction: Double
    public let memoryBytes: UInt64
    public var gpuFraction: Double
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double
    /// False for another user's process, whose CPU and memory read as 0.
    public let isReadable: Bool

    public init(
        pid: Int32 = 0,
        owner: ProcessOwner,
        cpuFraction: Double = 0,
        memoryBytes: UInt64 = 0,
        gpuFraction: Double = 0,
        downloadBytesPerSecond: Double = 0,
        uploadBytesPerSecond: Double = 0,
        isReadable: Bool = true
    ) {
        self.isReadable = isReadable
        self.pid = pid
        self.owner = owner
        self.cpuFraction = cpuFraction
        self.memoryBytes = memoryBytes
        self.gpuFraction = gpuFraction
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}

/// An app's combined use across all of its processes.
public struct AppUsage: Equatable, Sendable, Identifiable {
    public let identity: AppIdentity
    public var cpuFraction: Double
    public var memoryBytes: UInt64
    public var memoryFraction: Double
    public var gpuFraction: Double
    public var downloadBytesPerSecond: Double
    public var uploadBytesPerSecond: Double
    /// The readable processes behind this app. The system row's total can be larger, see `UsageAggregator`.
    public var processes: [ProcessUsage]
    public var destinations: [Destination]

    public var id: String { identity.id }
    public var networkBytesPerSecond: Double { downloadBytesPerSecond + uploadBytesPerSecond }
    public var processCount: Int { processes.count }
    public var processNames: [String] { Set(processes.map(\.owner.processName)).sorted() }

    public init(
        identity: AppIdentity,
        cpuFraction: Double = 0,
        memoryBytes: UInt64 = 0,
        memoryFraction: Double = 0,
        gpuFraction: Double = 0,
        downloadBytesPerSecond: Double = 0,
        uploadBytesPerSecond: Double = 0,
        processes: [ProcessUsage] = [],
        destinations: [Destination] = []
    ) {
        self.identity = identity
        self.cpuFraction = cpuFraction
        self.memoryBytes = memoryBytes
        self.memoryFraction = memoryFraction
        self.gpuFraction = gpuFraction
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.processes = processes
        self.destinations = destinations
    }
}

/// Whole-machine load for one sample. Nil means the figure could not be read.
public struct SystemLoad: Equatable, Sendable {
    public let cpuBusyFraction: Double?
    public let gpuBusyFraction: Double?
    public let memoryUsedBytes: UInt64?
    public let physicalMemoryBytes: UInt64

    public init(
        cpuBusyFraction: Double?,
        gpuBusyFraction: Double?,
        memoryUsedBytes: UInt64?,
        physicalMemoryBytes: UInt64
    ) {
        self.cpuBusyFraction = cpuBusyFraction
        self.gpuBusyFraction = gpuBusyFraction
        self.memoryUsedBytes = memoryUsedBytes
        self.physicalMemoryBytes = physicalMemoryBytes
    }
}

/// Whether a metric could be read in this sample.
public enum MetricStatus: Equatable, Sendable {
    case available
    case unavailable
}

/// Everything the UI needs for one moment in time.
public struct UsageSnapshot: Equatable, Sendable {
    public let apps: [AppUsage]
    public let load: SystemLoad
    public let processStatus: MetricStatus
    public let gpuStatus: MetricStatus
    public let networkStatus: MetricStatus
    public let backgroundPrograms: [BackgroundProgram]

    public init(
        apps: [AppUsage],
        load: SystemLoad,
        processStatus: MetricStatus,
        gpuStatus: MetricStatus,
        networkStatus: MetricStatus,
        backgroundPrograms: [BackgroundProgram] = []
    ) {
        self.apps = apps
        self.load = load
        self.processStatus = processStatus
        self.gpuStatus = gpuStatus
        self.networkStatus = networkStatus
        self.backgroundPrograms = backgroundPrograms
    }
}
