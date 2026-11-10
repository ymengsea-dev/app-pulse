import Testing
@testable import Domain

struct UsageAggregatorTests {
    private let chrome = AppIdentity(id: "/Applications/Chrome.app", name: "Chrome")
    private let load = SystemLoad(
        cpuBusyFraction: nil,
        gpuBusyFraction: nil,
        memoryUsedBytes: nil,
        physicalMemoryBytes: 1000
    )

    private func usage(_ apps: [AppUsage], _ id: String) -> AppUsage? {
        apps.first { $0.id == id }
    }

    @Test func helpersAddUpUnderTheirApp() {
        let apps = UsageAggregator.aggregate([
            ProcessUsage(owner: ProcessOwner(app: chrome, processName: "Chrome"), cpuFraction: 0.1, memoryBytes: 100),
            ProcessUsage(owner: ProcessOwner(app: chrome, processName: "Chrome Helper"), cpuFraction: 0.2, memoryBytes: 300),
        ], load: load)

        let result = usage(apps, chrome.id)
        #expect(result?.cpuFraction == 0.1 + 0.2)
        #expect(result?.memoryBytes == 400)
        #expect(result?.memoryFraction == 0.4)
        #expect(result?.processNames == ["Chrome", "Chrome Helper"])
    }

    @Test func sameNamedHelpersEachCountAsAProcess() {
        let helper = ProcessUsage(owner: ProcessOwner(app: chrome, processName: "Chrome Helper"))
        let apps = UsageAggregator.aggregate([helper, helper, helper], load: load)

        #expect(usage(apps, chrome.id)?.processCount == 3)
        #expect(usage(apps, chrome.id)?.processNames == ["Chrome Helper"])
    }

    @Test func unattributedLoadGoesToSystemRow() {
        let load = SystemLoad(cpuBusyFraction: 0.5, gpuBusyFraction: 0.4, memoryUsedBytes: 800, physicalMemoryBytes: 1000)
        let apps = UsageAggregator.aggregate([
            ProcessUsage(owner: ProcessOwner(app: chrome, processName: "Chrome"), cpuFraction: 0.2, memoryBytes: 300, gpuFraction: 0.1),
        ], load: load)

        let system = usage(apps, AppIdentity.system.id)
        #expect(abs((system?.cpuFraction ?? 0) - 0.3) < 0.0001)
        #expect(abs((system?.gpuFraction ?? 0) - 0.3) < 0.0001)
        #expect(system?.memoryBytes == 500)
    }

    @Test func systemRowExistsWithNoProcesses() {
        #expect(usage(UsageAggregator.aggregate([], load: load), AppIdentity.system.id) != nil)
    }

    @Test func overlappingGPUTimeScalesBackToWhole() {
        let other = AppIdentity(id: "/Applications/Game.app", name: "Game")
        let apps = UsageAggregator.aggregate([
            ProcessUsage(owner: ProcessOwner(app: chrome, processName: "Chrome"), gpuFraction: 1.5),
            ProcessUsage(owner: ProcessOwner(app: other, processName: "Game"), gpuFraction: 0.5),
        ], load: load)

        #expect(usage(apps, chrome.id)?.gpuFraction == 0.75)
        #expect(usage(apps, other.id)?.gpuFraction == 0.25)
    }

    @Test func cpuNeverExceedsWholeMachine() {
        let apps = UsageAggregator.aggregate([
            ProcessUsage(owner: ProcessOwner(app: chrome, processName: "Chrome"), cpuFraction: 1.4),
        ], load: load)
        #expect(usage(apps, chrome.id)?.cpuFraction == 1)
    }
}
