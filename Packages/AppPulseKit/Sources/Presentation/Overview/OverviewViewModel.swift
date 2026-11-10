import Domain
import Observation

enum UsageMetric: String, CaseIterable, Identifiable, Sendable {
    case memory, cpu, gpu, network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory: "Memory"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .network: "Network"
        }
    }

    var symbol: String {
        switch self {
        case .memory: "memorychip"
        case .cpu: "cpu"
        case .gpu: "cube"
        case .network: "network"
        }
    }

    func status(in snapshot: UsageSnapshot) -> MetricStatus {
        switch self {
        case .memory, .cpu: snapshot.processStatus
        case .gpu: snapshot.gpuStatus
        case .network: snapshot.networkStatus
        }
    }

    /// Shown in place of rows, so an idle page keeps its usual layout.
    var idleListMessage: String {
        switch self {
        case .network: "No app has an open connection right now."
        default: "Apps appear here as soon as they start using it."
        }
    }

    var phrase: String {
        switch self {
        case .memory: "memory"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .network: "network"
        }
    }
}

struct AppRowModel: Equatable, Identifiable {
    let id: String
    let name: String
    let bundlePath: String?
    let value: String
    let detail: String?
    let fraction: Double
    /// The app's processes for this metric while the row is expanded, otherwise nil.
    var processes: ProcessBreakdown.Result?
}

/// A whole-Mac figure beside the headline. Every tab uses the same value-over-label pairs.
struct TotalFigure: Equatable {
    enum Tone: Equatable {
        case used
        case available
        case neutral
    }

    let value: String
    let label: String
    let tone: Tone
}

struct Headline: Equatable {
    let value: String
    let phrase: String
    let totals: [TotalFigure]
}

enum OverviewState: Equatable {
    case loading
    case message(title: String, message: String)
    case ready(Headline, [AppRowModel])
}

/// Turns snapshots into what the overview page shows for the selected metric.
@MainActor
@Observable
final class OverviewViewModel {
    var metric: UsageMetric = .memory {
        didSet {
            guard metric != oldValue else { return }
            breakdownStabilizers = [:]
            refreshBreakdowns()
        }
    }

    /// Apps whose rows are open, kept per tab: opening a row on one tab leaves the others as they were.
    private var expandedByMetric: [UsageMetric: Set<String>] = [:]

    private var expanded: Set<String> {
        get { expandedByMetric[metric, default: []] }
        set { expandedByMetric[metric] = newValue }
    }

    private var snapshot: UsageSnapshot?
    private var stabilizers: [UsageMetric: RankStabilizer<String>] = [:]
    private var orders: [UsageMetric: [String]] = [:]
    private var breakdownStabilizers: [String: RankStabilizer<String>] = [:]
    private var breakdowns: [String: ProcessBreakdown.Result] = [:]

    /// An open row stays short. The app's page has the full list.
    static let shownProcesses = 8

    func toggleExpanded(_ appID: String) {
        if expanded.remove(appID) == nil {
            expanded.insert(appID)
        } else {
            breakdownStabilizers[appID] = nil
        }
        refreshBreakdowns()
    }

    private func refreshBreakdowns() {
        guard let snapshot else { return }
        var next: [String: ProcessBreakdown.Result] = [:]
        for app in snapshot.apps where expanded.contains(app.id) {
            let groups = ProcessBreakdown.groups(app, metric)
            let order = breakdownStabilizers[app.id, default: RankStabilizer()].update(values: groups.mapValues(\.value))
            next[app.id] = ProcessBreakdown.rows(groups, order: order, metric: metric, limit: Self.shownProcesses)
        }
        breakdowns = next
    }

    /// Figures below these would read as zero, so those apps are left off the list.
    private static let minimumFraction = 0.001
    private static let minimumMemoryBytes = 1_000_000.0
    private static let minimumBytesPerSecond = 100.0

    func apply(_ snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        for metric in UsageMetric.allCases {
            let values = Dictionary(uniqueKeysWithValues: snapshot.apps.map { ($0.id, Self.rawValue($0, metric)) })
            orders[metric] = stabilizers[metric, default: RankStabilizer()].update(values: values)
        }
        refreshBreakdowns()
    }

    var state: OverviewState {
        guard let snapshot else { return .loading }

        if let message = Self.unavailableMessage(metric, snapshot) {
            return .message(title: message.title, message: message.message)
        }

        let apps = Dictionary(uniqueKeysWithValues: snapshot.apps.map { ($0.id, $0) })
        let ordered = (orders[metric] ?? []).compactMap { apps[$0] }
        let active = ordered.filter { Self.isWorthShowing($0, metric) }
        // Idle moments keep the same page. Apps with an open connection stay listed at 0 B/s.
        let listed = ordered.filter { Self.isWorthShowing($0, metric) || (metric == .network && Self.hasOpenConnection($0)) }

        let networkTotal = snapshot.apps.reduce(0) { $0 + $1.networkBytesPerSecond }
        let rows = listed.map { app in
            var row = Self.makeRow(app, metric, networkTotal: networkTotal)
            row.processes = breakdowns[app.id]
            return row
        }
        return .ready(Self.makeHeadline(active, rows, metric, snapshot), rows)
    }

    private static func hasOpenConnection(_ app: AppUsage) -> Bool {
        app.destinations.contains(where: \.isActive)
    }

    private static func rawValue(_ app: AppUsage, _ metric: UsageMetric) -> Double {
        switch metric {
        case .memory: Double(app.memoryBytes)
        case .cpu: app.cpuFraction
        case .gpu: app.gpuFraction
        case .network: app.networkBytesPerSecond
        }
    }

    private static func isWorthShowing(_ app: AppUsage, _ metric: UsageMetric) -> Bool {
        switch metric {
        case .memory: Double(app.memoryBytes) >= minimumMemoryBytes
        case .cpu: app.cpuFraction >= minimumFraction
        case .gpu: app.gpuFraction >= minimumFraction
        case .network: app.networkBytesPerSecond >= minimumBytesPerSecond
        }
    }

    private static func makeRow(_ app: AppUsage, _ metric: UsageMetric, networkTotal: Double) -> AppRowModel {
        let value: String
        let detail: String?
        let fraction: Double

        switch metric {
        case .memory:
            value = UsageFormat.percent(app.memoryFraction)
            detail = UsageFormat.memory(app.memoryBytes)
            fraction = app.memoryFraction
        case .cpu:
            value = UsageFormat.percent(app.cpuFraction)
            detail = nil
            fraction = app.cpuFraction
        case .gpu:
            value = UsageFormat.percent(app.gpuFraction)
            detail = nil
            fraction = app.gpuFraction
        case .network:
            value = UsageFormat.speed(app.networkBytesPerSecond)
            detail = "↓ \(UsageFormat.speed(app.downloadBytesPerSecond))  ↑ \(UsageFormat.speed(app.uploadBytesPerSecond))"
            fraction = networkTotal > 0 ? app.networkBytesPerSecond / networkTotal : 0
        }

        return AppRowModel(
            id: app.id,
            name: app.identity.name,
            bundlePath: app.identity.bundlePath,
            value: value,
            detail: detail,
            fraction: fraction
        )
    }

    private static func makeHeadline(
        _ apps: [AppUsage],
        _ rows: [AppRowModel],
        _ metric: UsageMetric,
        _ snapshot: UsageSnapshot
    ) -> Headline {
        // The answer should name an app. The system row only leads when nothing else is using this metric.
        let leader = apps.first { !$0.identity.isSystem } ?? apps.first
        let leaderValue = leader.flatMap { leader in rows.first { $0.id == leader.id }?.value }
        let value = leaderValue ?? (metric == .network ? UsageFormat.speed(0) : UsageFormat.percent(0))
        let phrase = leader.map { leader in
            "\(leader.identity.isSystem ? "macOS" : leader.identity.name) is using the most \(metric.phrase)"
        } ?? "No app is using the \(metric.phrase) right now"

        return Headline(value: value, phrase: phrase, totals: makeTotals(metric, snapshot))
    }

    /// Used and Available for a resource with a fixed size. Network has no fixed size, so it shows its total.
    private static func makeTotals(_ metric: UsageMetric, _ snapshot: UsageSnapshot) -> [TotalFigure] {
        switch metric {
        case .memory:
            let physical = snapshot.load.physicalMemoryBytes
            let total = TotalFigure(value: UsageFormat.memory(physical), label: "Total", tone: .neutral)
            guard let used = snapshot.load.memoryUsedBytes else { return [total] }
            return [
                TotalFigure(value: UsageFormat.memory(used), label: "Used", tone: .used),
                TotalFigure(value: UsageFormat.memory(physical > used ? physical - used : 0), label: "Available", tone: .available),
                total,
            ]
        case .cpu:
            return fractionTotals(snapshot.load.cpuBusyFraction)
        case .gpu:
            return fractionTotals(snapshot.load.gpuBusyFraction)
        case .network:
            let total = snapshot.apps.reduce(0) { $0 + $1.networkBytesPerSecond }
            return [TotalFigure(value: UsageFormat.speed(total), label: "Total", tone: .neutral)]
        }
    }

    private static func fractionTotals(_ busy: Double?) -> [TotalFigure] {
        guard let busy else { return [] }
        let used = min(max(busy, 0), 1)
        return [
            TotalFigure(value: UsageFormat.percent(used), label: "Used", tone: .used),
            TotalFigure(value: UsageFormat.percent(1 - used), label: "Available", tone: .available),
        ]
    }

    private static func unavailableMessage(
        _ metric: UsageMetric,
        _ snapshot: UsageSnapshot
    ) -> (title: String, message: String)? {
        switch metric {
        case .memory where snapshot.processStatus == .unavailable,
             .cpu where snapshot.processStatus == .unavailable:
            ("\(metric.title) data isn't available", "AppPulse couldn't read app figures from macOS. Other tabs keep working.")
        case .gpu where snapshot.gpuStatus == .unavailable:
            ("GPU data isn't available on this Mac", "Per-app GPU figures need an Apple silicon Mac and a macOS version AppPulse can read. Other tabs keep working.")
        case .network where snapshot.networkStatus == .unavailable:
            ("Network data isn't available", "AppPulse couldn't read network figures from macOS. Other tabs keep working.")
        default:
            nil
        }
    }
}
