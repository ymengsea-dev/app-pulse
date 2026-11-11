import Testing
@testable import AppPulse

@MainActor
struct OverviewViewModelTests {
    private let slack = AppIdentity(id: "/Applications/Slack.app", name: "Slack", bundlePath: "/Applications/Slack.app")
    private let notes = AppIdentity(id: "/Applications/Notes.app", name: "Notes", bundlePath: "/Applications/Notes.app")

    private func snapshot(
        _ apps: [AppUsage],
        gpuStatus: MetricStatus = .available,
        networkStatus: MetricStatus = .available
    ) -> UsageSnapshot {
        UsageSnapshot(
            apps: apps,
            load: SystemLoad(
                cpuBusyFraction: 0.4,
                gpuBusyFraction: 0.2,
                memoryUsedBytes: 8_589_934_592,
                physicalMemoryBytes: 17_179_869_184
            ),
            processStatus: .available,
            gpuStatus: gpuStatus,
            networkStatus: networkStatus
        )
    }

    @Test func startsLoading() {
        #expect(OverviewViewModel().state == .loading)
    }

    @Test func headlineNamesTheTopApp() throws {
        let model = OverviewViewModel()
        model.apply(snapshot([
            AppUsage(identity: slack, memoryBytes: 5_440_000_000, memoryFraction: 0.34),
            AppUsage(identity: notes, memoryBytes: 200_000_000, memoryFraction: 0.0125),
        ]))

        guard case .ready(let headline, let rows) = model.state else {
            Issue.record("Expected a ready state")
            return
        }
        #expect(headline.value == "34%")
        #expect(headline.phrase == "Slack is using the most memory")
        #expect(headline.totals == [
            TotalFigure(value: "8.0 GB", label: "Used", tone: .used),
            TotalFigure(value: "8.0 GB", label: "Available", tone: .available),
            TotalFigure(value: "16 GB", label: "Total", tone: .neutral),
        ])
        #expect(rows.map(\.name) == ["Slack", "Notes"])
    }

    @Test func headlinePrefersARealAppOverTheSystemRow() {
        let model = OverviewViewModel()
        model.apply(snapshot([
            AppUsage(identity: .system, memoryBytes: 9_000_000_000, memoryFraction: 0.56),
            AppUsage(identity: slack, memoryBytes: 1_600_000_000, memoryFraction: 0.1),
        ]))

        guard case .ready(let headline, let rows) = model.state else {
            Issue.record("Expected a ready state")
            return
        }
        #expect(headline.value == "10%")
        #expect(headline.phrase == "Slack is using the most memory")
        #expect(rows.first?.name == "macOS & other")
    }

    @Test func idleNetworkKeepsThePageLayoutAtZero() {
        let model = OverviewViewModel()
        model.metric = .network
        model.apply(snapshot([AppUsage(identity: slack, memoryBytes: 100_000_000)]))

        guard case .ready(let headline, let rows) = model.state else {
            Issue.record("Expected the usual page, not a message")
            return
        }
        #expect(headline.value == "0 B/s")
        #expect(headline.phrase == "No app is using the network right now")
        #expect(headline.totals == [TotalFigure(value: "0 B/s", label: "Total", tone: .neutral)])
        #expect(rows.isEmpty)
    }

    @Test func idleNetworkStillListsAppsWithOpenConnections() {
        let model = OverviewViewModel()
        model.metric = .network
        let connected = AppUsage(identity: slack, destinations: [
            Destination(address: "203.0.113.5", isActive: true, lastSeen: .now),
        ])
        let closed = AppUsage(identity: notes, destinations: [
            Destination(address: "203.0.113.6", isActive: false, lastSeen: .now),
        ])
        model.apply(snapshot([connected, closed]))

        guard case .ready(let headline, let rows) = model.state else {
            Issue.record("Expected the usual page, not a message")
            return
        }
        #expect(headline.phrase == "No app is using the network right now")
        #expect(rows.map(\.name) == ["Slack"])
        #expect(rows.first?.value == "0 B/s")
    }

    private func slackWithHelpers() -> AppUsage {
        func helper(_ name: String, _ megabytes: UInt64, cpu: Double) -> ProcessUsage {
            ProcessUsage(owner: ProcessOwner(app: slack, processName: name), cpuFraction: cpu, memoryBytes: megabytes * 1_048_576)
        }
        return AppUsage(identity: slack, cpuFraction: 0.05, memoryBytes: 600 * 1_048_576, memoryFraction: 0.04, processes: [
            helper("Slack Helper", 200, cpu: 0.01),
            helper("Slack Helper", 200, cpu: 0.01),
            helper("Slack", 200, cpu: 0.03),
        ])
    }

    private func rows(_ model: OverviewViewModel) -> [AppRowModel] {
        if case .ready(_, let rows) = model.state { return rows }
        return []
    }

    @Test func rowsStartCollapsed() {
        let model = OverviewViewModel()
        model.apply(snapshot([slackWithHelpers()]))
        #expect(rows(model).first?.processes == nil)
    }

    @Test func expandingARowShowsItsGroupedProcesses() {
        let model = OverviewViewModel()
        model.apply(snapshot([slackWithHelpers()]))
        model.toggleExpanded(slack.id)

        let processes = rows(model).first { $0.id == slack.id }?.processes
        #expect(processes?.rows.map(\.name) == ["Slack Helper", "Slack"])
        #expect(processes?.rows.first?.count == 2)
        #expect(processes?.rows.first?.value == "400 MB")
    }

    @Test func openRowsBelongToTheirTab() {
        let model = OverviewViewModel()
        model.apply(snapshot([slackWithHelpers()]))
        model.toggleExpanded(slack.id)

        model.metric = .cpu
        #expect(rows(model).first { $0.id == slack.id }?.processes == nil)

        model.metric = .memory
        #expect(rows(model).first { $0.id == slack.id }?.processes?.rows.first?.value == "400 MB")
    }

    @Test func openRowShowsItsOwnTabsFigures() {
        let model = OverviewViewModel()
        model.apply(snapshot([slackWithHelpers()]))
        model.metric = .cpu
        model.toggleExpanded(slack.id)

        let processes = rows(model).first { $0.id == slack.id }?.processes
        #expect(processes?.rows.map(\.name) == ["Slack", "Slack Helper"])
        #expect(processes?.rows.first?.value == "3.0%")
    }

    @Test func expandedRowStaysOpenAcrossUpdatesAndCloses() {
        let model = OverviewViewModel()
        model.apply(snapshot([slackWithHelpers()]))
        model.toggleExpanded(slack.id)
        model.apply(snapshot([slackWithHelpers()]))
        #expect(rows(model).first { $0.id == slack.id }?.processes != nil)

        model.toggleExpanded(slack.id)
        #expect(rows(model).first { $0.id == slack.id }?.processes == nil)
    }

    @Test func cpuShowsUsedAndAvailable() {
        let model = OverviewViewModel()
        model.metric = .cpu
        model.apply(snapshot([AppUsage(identity: slack, cpuFraction: 0.2)]))

        guard case .ready(let headline, _) = model.state else {
            Issue.record("Expected a ready state")
            return
        }
        #expect(headline.totals == [
            TotalFigure(value: "40%", label: "Used", tone: .used),
            TotalFigure(value: "60%", label: "Available", tone: .available),
        ])
    }

    @Test func idleGPUKeepsThePageLayoutAtZero() {
        let model = OverviewViewModel()
        model.metric = .gpu
        model.apply(snapshot([AppUsage(identity: slack, memoryBytes: 100_000_000)]))

        guard case .ready(let headline, let rows) = model.state else {
            Issue.record("Expected the usual page, not a message")
            return
        }
        #expect(headline.value == "0.0%")
        #expect(headline.phrase == "No app is using the GPU right now")
        #expect(rows.isEmpty)
    }

    @Test func tinyFiguresAreLeftOffTheList() {
        let model = OverviewViewModel()
        model.metric = .cpu
        model.apply(snapshot([
            AppUsage(identity: slack, cpuFraction: 0.2),
            AppUsage(identity: notes, cpuFraction: 0.0001),
        ]))

        guard case .ready(_, let rows) = model.state else {
            Issue.record("Expected a ready state")
            return
        }
        #expect(rows.map(\.name) == ["Slack"])
    }

    @Test func unavailableMetricSaysSoWithoutAffectingOthers() {
        let model = OverviewViewModel()
        model.apply(snapshot([AppUsage(identity: slack, memoryBytes: 100_000_000)], gpuStatus: .unavailable))

        model.metric = .gpu
        guard case .message(let title, _) = model.state else {
            Issue.record("Expected a message state")
            return
        }
        #expect(title == "GPU data isn't available on this Mac")

        model.metric = .memory
        guard case .ready = model.state else {
            Issue.record("Expected a ready state")
            return
        }
    }

    @Test func networkShowsSpeedAndShareOfTraffic() {
        let model = OverviewViewModel()
        model.metric = .network
        model.apply(snapshot([
            AppUsage(identity: slack, downloadBytesPerSecond: 3_000_000, uploadBytesPerSecond: 0),
            AppUsage(identity: notes, downloadBytesPerSecond: 500_000, uploadBytesPerSecond: 500_000),
        ]))

        guard case .ready(let headline, let rows) = model.state else {
            Issue.record("Expected a ready state")
            return
        }
        #expect(headline.value == "3.0 MB/s")
        #expect(headline.totals == [TotalFigure(value: "4.0 MB/s", label: "Total", tone: .neutral)])
        #expect(rows.first?.fraction == 0.75)
        #expect(rows.first?.detail == "↓ 3.0 MB/s  ↑ 0 B/s")
    }
}
