import Testing
@testable import AppPulse

@MainActor
private final class StubTerminator: AppTerminating {
    var isAppRunning = true
    var closesOnQuit = false
    var closesOnForceQuit = true
    private(set) var forceQuitCount = 0

    func canTerminate(bundleIdentifier: String) -> Bool { isAppRunning }
    func isRunning(bundleIdentifier: String) -> Bool { isAppRunning }

    func requestQuit(bundleIdentifier: String) {
        if closesOnQuit { isAppRunning = false }
    }

    func forceQuit(bundleIdentifier: String) {
        forceQuitCount += 1
        if closesOnForceQuit { isAppRunning = false }
    }
}

@MainActor
struct AppDetailViewModelTests {
    private let app = AppIdentity(id: "/Applications/Slack.app", name: "Slack", bundleIdentifier: "com.example.slack")

    private func makeModel(_ terminator: StubTerminator = StubTerminator(), metric: UsageMetric = .memory) -> AppDetailViewModel {
        AppDetailViewModel(metric: metric, quitUseCase: QuitAppUseCase(
            terminator: terminator,
            gracePeriod: .milliseconds(30),
            pollInterval: .milliseconds(5)
        ))
    }

    @Test func quitThatWorksEndsClosed() async {
        let terminator = StubTerminator()
        terminator.closesOnQuit = true
        let model = makeModel(terminator)

        await model.quit(app)

        #expect(model.quitState == .closed)
        #expect(!model.canQuit(app))
    }

    @Test func stuckAppOffersForceQuitButDoesNotRunIt() async {
        let terminator = StubTerminator()
        let model = makeModel(terminator)

        await model.quit(app)

        #expect(model.quitState == .stillOpen)
        #expect(terminator.forceQuitCount == 0)
    }

    @Test func forceQuitIsRefusedBeforeANormalQuitFails() async {
        let terminator = StubTerminator()
        let model = makeModel(terminator)

        await model.forceQuit(app)

        #expect(model.quitState == .idle)
        #expect(terminator.forceQuitCount == 0)
    }

    @Test func forceQuitAfterFailedQuitCloses() async {
        let terminator = StubTerminator()
        let model = makeModel(terminator)

        await model.quit(app)
        await model.forceQuit(app)

        #expect(model.quitState == .closed)
        #expect(terminator.forceQuitCount == 1)
    }

    @Test func systemRowCanNotBeQuit() {
        #expect(!makeModel(StubTerminator()).canQuit(.system))
    }

    private func process(_ name: String, memory: UInt64 = 0, cpu: Double = 0, identity: AppIdentity? = nil) -> ProcessUsage {
        ProcessUsage(owner: ProcessOwner(app: identity ?? app, processName: name), cpuFraction: cpu, memoryBytes: memory)
    }

    @Test func memoryPageGroupsSameNamedHelpers() {
        let model = makeModel(metric: .memory)
        let usage = AppUsage(identity: app, memoryBytes: 600 * 1_048_576, memoryFraction: 0.04, processes: [
            process("Slack Helper", memory: 200 * 1_048_576),
            process("Slack Helper", memory: 200 * 1_048_576),
            process("Slack", memory: 200 * 1_048_576),
        ])

        model.apply(usage, status: .available)

        #expect(model.hero == DetailHero(value: "600 MB", caption: "4.0% of your Mac's memory"))
        #expect(model.rows.map(\.name) == ["Slack Helper", "Slack"])
        #expect(model.rows.first?.count == 2)
        #expect(model.rows.first?.value == "400 MB")
        #expect(model.rows.first?.fraction == 1)
    }

    @Test func cpuPageLeavesOutIdleProcesses() {
        let model = makeModel(metric: .cpu)
        let usage = AppUsage(identity: app, cpuFraction: 0.12, processes: [
            process("Slack", cpu: 0.12),
            process("Slack Helper", cpu: 0),
        ])

        model.apply(usage, status: .available)

        #expect(model.hero == DetailHero(value: "12%", caption: "of your Mac's CPU"))
        #expect(model.rows.map(\.name) == ["Slack"])
    }

    @Test func networkPageHasNoProcessRows() {
        let model = makeModel(metric: .network)
        let usage = AppUsage(identity: app, downloadBytesPerSecond: 2_000_000, uploadBytesPerSecond: 100_000, processes: [
            process("Slack", memory: 200_000_000),
        ])

        model.apply(usage, status: .available)

        #expect(model.hero == DetailHero(value: "2.1 MB/s", caption: "↓ 2.0 MB/s  ↑ 100 KB/s"))
        #expect(model.rows.isEmpty)
    }

    @Test func systemPageShowsUnreadableShareSoRowsAddUp() {
        let model = makeModel(metric: .cpu)
        let usage = AppUsage(identity: .system, cpuFraction: 0.2, processes: [
            process("WindowServer", cpu: 0.05, identity: .system),
        ])

        model.apply(usage, status: .available)

        #expect(model.rows.map(\.id) == [ProcessBreakdown.unreadableRowID, "WindowServer"])
        #expect(model.rows.first?.value == "15%")
    }

    @Test func unavailableMetricSaysSo() {
        let model = makeModel(metric: .gpu)
        model.apply(AppUsage(identity: app, gpuFraction: 0.3), status: .unavailable)

        #expect(model.hero.value == "—")
        #expect(model.hero.caption == "GPU data isn't available right now")
        #expect(model.rows.isEmpty)
    }

    @Test func closedAppShowsNoFigures() {
        let model = makeModel(metric: .memory)
        model.apply(nil, status: .available)

        #expect(model.hero.caption == "No longer running")
        #expect(model.rows.isEmpty)
    }
}
