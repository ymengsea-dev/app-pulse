import Application
import SwiftUI

/// The app's single window: usage metrics and the privacy view in the sidebar, their page in the detail column.
public struct RootView: View {
    private let store: MonitorStore
    private let quitUseCase: QuitAppUseCase
    @State private var overview = OverviewViewModel()
    @State private var background = BackgroundViewModel()
    @State private var item: SidebarItem = .metric(.memory)
    @State private var path: [AppRoute] = []

    public init(store: MonitorStore, quitUseCase: QuitAppUseCase) {
        self.store = store
        self.quitUseCase = quitUseCase
    }

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { item },
            set: { newItem in
                guard let newItem else { return }
                item = newItem
                if case .metric(let metric) = newItem { overview.metric = metric }
                // Picking an item always shows its list, even from an app's page.
                path = []
            }
        )
    }

    public var body: some View {
        NavigationSplitView {
            // Rows are tagged with the item itself, so the tag matches the selection's type.
            List(selection: selection) {
                Section("Usage") {
                    ForEach(UsageMetric.allCases) { metric in
                        Label(metric.title, systemImage: metric.symbol).tag(SidebarItem.metric(metric))
                    }
                }
                Section("Privacy") {
                    Label("Background", systemImage: "eye").tag(SidebarItem.background)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            NavigationStack(path: $path) {
                Group {
                    switch item {
                    case .metric: OverviewView(model: overview)
                    case .background: BackgroundView(model: background)
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    AppDetailView(route: route, store: store, quitUseCase: quitUseCase)
                }
            }
            .quietToolbar()
            // Each column sets its own minimum. A minimum on the whole split view also applied to the
            // detail column, so showing the sidebar overflowed a narrow window.
            .navigationSplitViewColumnWidth(min: 560, ideal: 760)
            .frame(minHeight: 560)
        }
        .tint(Theme.accent)
        .background {
            WindowVisibilityObserver { isVisible in
                store.setWindowVisible(isVisible)
            }
        }
        .onChange(of: store.snapshot) { _, snapshot in
            guard let snapshot else { return }
            overview.apply(snapshot)
            background.apply(snapshot)
        }
    }
}
