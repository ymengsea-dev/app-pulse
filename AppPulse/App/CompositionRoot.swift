/// The only place that chooses concrete implementations.
@MainActor
enum CompositionRoot {
    static func makeStore() -> MonitorStore {
        let engine = MonitoringEngine(providers: .init(
            processes: LibprocMetricsProvider(),
            gpu: IOKitGPUMetricsProvider(),
            network: NettopMetricsProvider(),
            system: MachSystemMetricsProvider(),
            owners: BundleAppIdentityResolver(),
            hostNames: CachingReverseDNSResolver(),
            signatures: SecCodeSignatureChecker(),
            foregroundApps: WorkspaceForegroundApps()
        ))
        return MonitorStore(engine: engine)
    }

    static func makeQuitUseCase() -> QuitAppUseCase {
        QuitAppUseCase(terminator: WorkspaceAppTerminator())
    }
}
