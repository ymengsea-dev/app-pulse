import Application
import Domain
import Observation

/// Holds the latest snapshot for the UI, and samples only while the window can be seen.
@MainActor
@Observable
public final class MonitorStore {
    private(set) var snapshot: UsageSnapshot?

    @ObservationIgnored private let engine: MonitoringEngine
    @ObservationIgnored private var transition: Task<Void, Never>?

    public init(engine: MonitoringEngine) {
        self.engine = engine
    }

    func setWindowVisible(_ isVisible: Bool) {
        // Chained, so a quick hide and show are applied in order.
        let previous = transition
        let engine = self.engine
        transition = Task { [weak self] in
            await previous?.value
            if isVisible {
                await engine.start { [weak self] snapshot in
                    await self?.receive(snapshot)
                }
            } else {
                await engine.pause()
            }
        }
    }

    private func receive(_ snapshot: UsageSnapshot) {
        self.snapshot = snapshot
    }
}
