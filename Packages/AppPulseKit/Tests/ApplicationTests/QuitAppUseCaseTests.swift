import Domain
import Testing
@testable import Application

@MainActor
struct QuitAppUseCaseTests {
    private let slack = AppIdentity(id: "/Applications/Slack.app", name: "Slack", bundleIdentifier: "com.example.slack")

    private func makeUseCase(_ terminator: FakeTerminator) -> QuitAppUseCase {
        QuitAppUseCase(terminator: terminator, gracePeriod: .milliseconds(50), pollInterval: .milliseconds(5))
    }

    @Test func appThatClosesReportsClosed() async {
        let terminator = FakeTerminator(running: ["com.example.slack"])
        #expect(await makeUseCase(terminator).quit(slack) == .closed)
        #expect(terminator.quitRequests == ["com.example.slack"])
    }

    @Test func appThatStaysOpenIsNotForceQuitAutomatically() async {
        let terminator = FakeTerminator(running: ["com.example.slack"])
        terminator.closesOnQuit = false
        #expect(await makeUseCase(terminator).quit(slack) == .stillOpen)
        #expect(terminator.forceQuitRequests.isEmpty)
    }

    @Test func forceQuitClosesAStuckApp() async {
        let terminator = FakeTerminator(running: ["com.example.slack"])
        terminator.closesOnQuit = false
        #expect(await makeUseCase(terminator).forceQuit(slack) == .closed)
        #expect(terminator.forceQuitRequests == ["com.example.slack"])
    }

    @Test func systemRowCanNeverBeQuit() async {
        let terminator = FakeTerminator(running: [])
        let useCase = makeUseCase(terminator)
        #expect(!useCase.canQuit(.system))
        #expect(await useCase.quit(.system) == .notQuittable)
        #expect(await useCase.forceQuit(.system) == .notQuittable)
        #expect(terminator.quitRequests.isEmpty)
    }

    @Test func appThatIsNotRunningCannotBeQuit() async {
        let terminator = FakeTerminator(running: [])
        #expect(await makeUseCase(terminator).quit(slack) == .notQuittable)
    }
}
