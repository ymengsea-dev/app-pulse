import Domain

/// One process in an app's breakdown. Processes with the same name are grouped.
struct ProcessRowModel: Equatable, Identifiable {
    let id: String
    let name: String
    let count: Int
    let value: String
    let fraction: Double
}

/// Splits an app's use of one metric into its processes. Shared by the overview list and the app page.
enum ProcessBreakdown {
    /// The system row's share of work done by processes AppPulse can't read.
    static let unreadableRowID = "unreadable"

    struct Group: Equatable {
        let id: String
        let name: String
        var count: Int
        var value: Double
    }

    struct Result: Equatable {
        let rows: [ProcessRowModel]
        let hiddenCount: Int
    }

    /// Groups processes by name. Keyed by group id, ready for a `RankStabilizer`.
    static func groups(_ app: AppUsage, _ metric: UsageMetric) -> [String: Group] {
        var groups: [String: Group] = [:]
        for process in app.processes {
            let name = process.owner.processName
            groups[name, default: Group(id: name, name: name, count: 0, value: 0)].count += 1
            groups[name]?.value += value(of: process, metric)
        }

        // The system row also holds work from processes that can't be read. Show it, so the rows add up.
        if app.identity.isSystem {
            let listed = groups.values.reduce(0) { $0 + $1.value }
            let remainder = total(of: app, metric) - listed
            if remainder > 0 {
                groups[unreadableRowID] = Group(id: unreadableRowID, name: "Processes AppPulse can't read", count: 0, value: remainder)
            }
        }
        return groups
    }

    /// Rows in the given order, without figures that would read as zero, capped at `limit`.
    /// Bars are relative to the largest group, so small apps still show their shape.
    static func rows(_ groups: [String: Group], order: [String], metric: UsageMetric, limit: Int) -> Result {
        let visible = order.compactMap { groups[$0] }.filter { $0.value >= minimumValue(metric) }
        let largest = visible.map(\.value).max() ?? 0
        let rows = visible.prefix(limit).map { group in
            ProcessRowModel(
                id: group.id,
                name: group.name,
                count: group.count,
                value: format(group.value, metric),
                fraction: largest > 0 ? group.value / largest : 0
            )
        }
        return Result(rows: rows, hiddenCount: max(visible.count - limit, 0))
    }

    private static func value(of process: ProcessUsage, _ metric: UsageMetric) -> Double {
        switch metric {
        case .memory: Double(process.memoryBytes)
        case .cpu: process.cpuFraction
        case .gpu: process.gpuFraction
        case .network: process.downloadBytesPerSecond + process.uploadBytesPerSecond
        }
    }

    private static func total(of app: AppUsage, _ metric: UsageMetric) -> Double {
        switch metric {
        case .memory: Double(app.memoryBytes)
        case .cpu: app.cpuFraction
        case .gpu: app.gpuFraction
        case .network: app.networkBytesPerSecond
        }
    }

    /// Figures below these would read as zero.
    private static func minimumValue(_ metric: UsageMetric) -> Double {
        switch metric {
        case .memory: 1_000_000
        case .cpu, .gpu: 0.001
        case .network: 100
        }
    }

    private static func format(_ value: Double, _ metric: UsageMetric) -> String {
        switch metric {
        case .memory: UsageFormat.memory(UInt64(value))
        case .cpu, .gpu: UsageFormat.percent(value)
        case .network: UsageFormat.speed(value)
        }
    }
}
