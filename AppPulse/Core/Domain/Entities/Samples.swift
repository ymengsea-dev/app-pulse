/// One reading of a process's cumulative CPU time and current memory.
/// Both are nil for another user's process, such as root's, which can be listed but not read.
public struct ProcessSample: Equatable, Sendable {
    public let pid: Int32
    public let cpuNanoseconds: UInt64?
    public let memoryBytes: UInt64?

    public var isReadable: Bool { cpuNanoseconds != nil }

    public init(pid: Int32, cpuNanoseconds: UInt64?, memoryBytes: UInt64?) {
        self.pid = pid
        self.cpuNanoseconds = cpuNanoseconds
        self.memoryBytes = memoryBytes
    }
}

/// One reading of per-process cumulative GPU time and the device's overall load.
public struct GPUSample: Equatable, Sendable {
    public let nanosecondsByPID: [Int32: UInt64]
    public let deviceBusyFraction: Double?

    public init(nanosecondsByPID: [Int32: UInt64], deviceBusyFraction: Double?) {
        self.nanosecondsByPID = nanosecondsByPID
        self.deviceBusyFraction = deviceBusyFraction
    }
}

/// A remote endpoint a process is connected to.
public struct NetworkConnection: Hashable, Sendable {
    public let remoteAddress: String
    public let remotePort: Int

    public init(remoteAddress: String, remotePort: Int) {
        self.remoteAddress = remoteAddress
        self.remotePort = remotePort
    }
}

/// One reading of a process's cumulative traffic and open connections.
public struct NetworkSample: Equatable, Sendable {
    public let pid: Int32
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let connections: [NetworkConnection]

    public init(pid: Int32, bytesIn: UInt64, bytesOut: UInt64, connections: [NetworkConnection]) {
        self.pid = pid
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.connections = connections
    }
}

/// One reading of whole-machine figures. CPU ticks are cumulative.
/// Optional fields are nil when the OS refused the query.
public struct SystemSample: Equatable, Sendable {
    public let logicalCores: Int
    public let physicalMemoryBytes: UInt64
    public let memoryUsedBytes: UInt64?
    public let cpuBusyTicks: UInt64?
    public let cpuTotalTicks: UInt64?

    public init(
        logicalCores: Int,
        physicalMemoryBytes: UInt64,
        memoryUsedBytes: UInt64?,
        cpuBusyTicks: UInt64?,
        cpuTotalTicks: UInt64?
    ) {
        self.logicalCores = logicalCores
        self.physicalMemoryBytes = physicalMemoryBytes
        self.memoryUsedBytes = memoryUsedBytes
        self.cpuBusyTicks = cpuBusyTicks
        self.cpuTotalTicks = cpuTotalTicks
    }
}
