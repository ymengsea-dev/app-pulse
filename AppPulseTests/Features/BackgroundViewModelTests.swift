import Testing
@testable import AppPulse

@MainActor
struct BackgroundViewModelTests {
    private func snapshot(_ programs: [BackgroundProgram]) -> UsageSnapshot {
        UsageSnapshot(
            apps: [],
            load: SystemLoad(cpuBusyFraction: nil, gpuBusyFraction: nil, memoryUsedBytes: nil, physicalMemoryBytes: 1),
            processStatus: .available,
            gpuStatus: .available,
            networkStatus: .available,
            backgroundPrograms: programs
        )
    }

    private let programs = [
        BackgroundProgram(path: "/usr/libexec/agent", name: "agent", processCount: 1, isReadable: true, signer: .apple),
        BackgroundProgram(path: "/Library/Google/updater", name: "updater", processCount: 1, isReadable: true, signer: .developer("Google LLC")),
        BackgroundProgram(path: "/Users/me/bin/tool", name: "tool", processCount: 2, isReadable: true, signer: .unsigned),
        BackgroundProgram(path: "/opt/thing", name: "thing", processCount: 1, isReadable: false, signer: nil),
    ]

    private func ready(_ model: BackgroundViewModel) -> (Headline, [BackgroundRowModel])? {
        if case .ready(let headline, let rows, _) = model.state { return (headline, rows) }
        return nil
    }

    @Test func startsLoading() {
        #expect(BackgroundViewModel().state == .loading)
    }

    @Test func applesProgramsAreHiddenByDefault() {
        let model = BackgroundViewModel()
        model.apply(snapshot(programs))
        #expect(ready(model)?.1.map(\.name) == ["tool", "updater"])
    }

    @Test func showingAllIncludesAppleLast() {
        let model = BackgroundViewModel()
        model.apply(snapshot(programs))
        model.showsApplePrograms = true
        #expect(ready(model)?.1.map(\.name) == ["tool", "updater", "agent"])
    }

    @Test func headlineCountsBySigner() {
        let model = BackgroundViewModel()
        model.apply(snapshot(programs))
        let headline = ready(model)?.0
        #expect(headline?.value == "2")
        #expect(headline?.phrase == "background programs not from Apple so far")
        #expect(headline?.totals == [
            TotalFigure(value: "1", label: "Unverified", tone: .used),
            TotalFigure(value: "1", label: "Developer", tone: .neutral),
            TotalFigure(value: "1", label: "Apple", tone: .available),
        ])
    }

    @Test func badgesSayWhoSignedIt() {
        let model = BackgroundViewModel()
        model.apply(snapshot(programs))
        let badges = ready(model)?.1.map(\.badge)
        #expect(badges == [
            SignerBadge(title: "Unsigned", tone: .concern),
            SignerBadge(title: "Google LLC", tone: .neutral),
        ])
    }

    @Test func uncheckedProgramsAreNeitherCountedNorListed() {
        let model = BackgroundViewModel()
        model.apply(snapshot(programs))
        guard case .ready(_, let rows, let checkingCount) = model.state else {
            Issue.record("Expected a ready state")
            return
        }
        #expect(checkingCount == 1)
        #expect(!rows.contains { $0.name == "thing" })
    }

    @Test func checkedEverythingDropsSoFar() {
        let model = BackgroundViewModel()
        model.apply(snapshot(Array(programs.prefix(3))))
        #expect(ready(model)?.0.phrase == "background programs not from Apple")
    }

    @Test func unreadableProgramExplainsMissingFigures() {
        let model = BackgroundViewModel()
        var unreadable = programs[3]
        unreadable.signer = .developer("Example Inc")
        model.apply(snapshot([unreadable]))
        let thing = ready(model)?.1.first { $0.name == "thing" }
        #expect(thing?.detail == "Runs as another user, so its figures need admin access")
    }

    @Test func singleProgramUsesSingularPhrase() {
        let model = BackgroundViewModel()
        model.apply(snapshot([programs[2]]))
        #expect(ready(model)?.0.phrase == "background program not from Apple")
    }
}
