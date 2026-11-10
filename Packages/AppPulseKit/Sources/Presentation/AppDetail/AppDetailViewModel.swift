import Application
import Domain
import Observation

enum QuitState: Equatable {
    case idle
    case quitting
    case stillOpen
    case closed
}

/// The big figure at the top of an app's page.
struct DetailHero: Equatable {
    let value: String
    let caption: String
}

/// Shows one app through one metric, and runs its quit flow.
/// Force Quit is only reachable after a normal quit fails.
@MainActor
@Observable
final class AppDetailViewModel {
    let metric: UsageMetric
    private(set) var quitState: QuitState = .idle
    private(set) var hero = DetailHero(value: "—", caption: "Measuring…")
    private(set) var rows: [ProcessRowModel] = []
    private(set) var hiddenRowCount = 0

    @ObservationIgnored private let quitUseCase: QuitAppUseCase
    @ObservationIgnored private var stabilizer = RankStabilizer<String>()

    /// Long breakdowns are cut short, because the full list would not help anyone.
    static let shownRows = 25

    init(metric: UsageMetric, quitUseCase: QuitAppUseCase) {
        self.metric = metric
        self.quitUseCase = quitUseCase
    }

    func apply(_ app: AppUsage?, status: MetricStatus) {
        guard let app, quitState != .closed else {
            hero = DetailHero(value: "—", caption: "No longer running")
            rows = []
            hiddenRowCount = 0
            return
        }
        guard status == .available else {
            hero = DetailHero(value: "—", caption: "\(metric.title) data isn't available right now")
            rows = []
            hiddenRowCount = 0
            return
        }

        hero = Self.makeHero(app, metric)
        guard metric != .network else { return }

        let groups = ProcessBreakdown.groups(app, metric)
        let order = stabilizer.update(values: groups.mapValues(\.value))
        let result = ProcessBreakdown.rows(groups, order: order, metric: metric, limit: Self.shownRows)
        rows = result.rows
        hiddenRowCount = result.hiddenCount
    }

    func canQuit(_ app: AppIdentity) -> Bool {
        quitState != .closed && quitUseCase.canQuit(app)
    }

    func quit(_ app: AppIdentity) async {
        quitState = .quitting
        apply(await quitUseCase.quit(app))
    }

    func forceQuit(_ app: AppIdentity) async {
        guard quitState == .stillOpen else { return }
        quitState = .quitting
        apply(await quitUseCase.forceQuit(app))
    }

    func dismissStillOpen() {
        if quitState == .stillOpen { quitState = .idle }
    }

    private func apply(_ outcome: QuitOutcome) {
        switch outcome {
        case .closed: quitState = .closed
        case .stillOpen: quitState = .stillOpen
        case .notQuittable: quitState = .idle
        }
    }

    private static func makeHero(_ app: AppUsage, _ metric: UsageMetric) -> DetailHero {
        switch metric {
        case .memory:
            DetailHero(value: UsageFormat.memory(app.memoryBytes), caption: "\(UsageFormat.percent(app.memoryFraction)) of your Mac's memory")
        case .cpu:
            DetailHero(value: UsageFormat.percent(app.cpuFraction), caption: "of your Mac's CPU")
        case .gpu:
            DetailHero(value: UsageFormat.percent(app.gpuFraction), caption: "of the GPU")
        case .network:
            DetailHero(
                value: UsageFormat.speed(app.networkBytesPerSecond),
                caption: "↓ \(UsageFormat.speed(app.downloadBytesPerSecond))  ↑ \(UsageFormat.speed(app.uploadBytesPerSecond))"
            )
        }
    }

}
