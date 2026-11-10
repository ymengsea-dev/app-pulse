import Domain

public enum QuitOutcome: Equatable, Sendable {
    case closed
    case stillOpen
    case notQuittable
}

/// Asks an app to close, and reports whether it actually did.
@MainActor
public struct QuitAppUseCase {
    private let terminator: any AppTerminating
    private let gracePeriod: Duration
    private let pollInterval: Duration

    public init(
        terminator: any AppTerminating,
        gracePeriod: Duration = .seconds(5),
        pollInterval: Duration = .milliseconds(200)
    ) {
        self.terminator = terminator
        self.gracePeriod = gracePeriod
        self.pollInterval = pollInterval
    }

    public func canQuit(_ app: AppIdentity) -> Bool {
        guard let identifier = app.bundleIdentifier else { return false }
        return terminator.canTerminate(bundleIdentifier: identifier)
    }

    public func quit(_ app: AppIdentity) async -> QuitOutcome {
        guard canQuit(app), let identifier = app.bundleIdentifier else { return .notQuittable }
        terminator.requestQuit(bundleIdentifier: identifier)
        return await waitForExit(identifier)
    }

    public func forceQuit(_ app: AppIdentity) async -> QuitOutcome {
        guard canQuit(app), let identifier = app.bundleIdentifier else { return .notQuittable }
        terminator.forceQuit(bundleIdentifier: identifier)
        return await waitForExit(identifier)
    }

    private func waitForExit(_ identifier: String) async -> QuitOutcome {
        let clock = ContinuousClock()
        let deadline = clock.now + gracePeriod
        while clock.now < deadline {
            if !terminator.isRunning(bundleIdentifier: identifier) { return .closed }
            try? await Task.sleep(for: pollInterval)
        }
        return terminator.isRunning(bundleIdentifier: identifier) ? .stillOpen : .closed
    }
}
