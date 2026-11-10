import Application
import Domain
import SwiftUI

/// One app, seen through the metric it was opened from. Only the Network page lists connections.
struct AppDetailView: View {
    let route: AppRoute
    let store: MonitorStore

    @State private var model: AppDetailViewModel
    @State private var lastKnown: AppUsage?
    @State private var isConfirmingQuit = false
    @State private var isConfirmingForceQuit = false

    init(route: AppRoute, store: MonitorStore, quitUseCase: QuitAppUseCase) {
        self.route = route
        self.store = store
        _model = State(initialValue: AppDetailViewModel(metric: route.metric, quitUseCase: quitUseCase))
    }

    private var liveApp: AppUsage? {
        store.snapshot?.apps.first { $0.id == route.appID }
    }

    private var metricStatus: MetricStatus {
        store.snapshot.map(route.metric.status(in:)) ?? .unavailable
    }

    var body: some View {
        Group {
            if let app = liveApp ?? lastKnown {
                page(app)
            } else {
                MessageView(title: "This app has closed", message: "It's no longer running, so there's nothing to show.")
            }
        }
        .paperBackground()
        .navigationTitle(liveApp?.identity.name ?? lastKnown?.identity.name ?? "App")
        .quietToolbar()
        .onChange(of: liveApp, initial: true) { _, app in
            if let app { lastKnown = app }
            model.apply(app, status: metricStatus)
        }
        .onChange(of: model.quitState) {
            model.apply(liveApp, status: metricStatus)
        }
    }

    private func page(_ app: AppUsage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header(app)
                if model.quitState == .stillOpen {
                    stillOpenBanner(app)
                } else if model.quitState == .closed {
                    closedBanner(app)
                }
                hero
                if isShowingData {
                    if route.metric == .network {
                        destinations(app)
                    } else {
                        processes(app)
                    }
                }
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private var isShowingData: Bool {
        liveApp != nil && model.quitState != .closed && metricStatus == .available
    }

    private func header(_ app: AppUsage) -> some View {
        HStack(spacing: 16) {
            AppIconView(bundlePath: app.identity.bundlePath, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.identity.name)
                    .font(Theme.pageTitle)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle(app))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 16)
            if model.canQuit(app.identity) {
                Button("Quit…") { isConfirmingQuit = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.quitState == .quitting)
                    .alert("Quit \(app.identity.name)?", isPresented: $isConfirmingQuit) {
                        Button("Cancel", role: .cancel) {}
                        Button("Quit") { Task { await model.quit(app.identity) } }
                    } message: {
                        Text("\(app.identity.name) may ask you to save your work first.")
                    }
            }
        }
    }

    private func subtitle(_ app: AppUsage) -> String {
        if app.identity.isSystem { return "Background parts of macOS, and work no app can be tied to" }
        if liveApp == nil || model.quitState == .closed { return "No longer running" }
        return "Running \(UsageFormat.count(app.processCount, "process"))"
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.metric.title)
                .font(.callout)
                .foregroundStyle(Theme.inkSecondary)
            Text(model.hero.value)
                .font(Theme.display(54, weight: .light))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(model.hero.caption)
                .font(.title3)
                .foregroundStyle(Theme.inkSecondary)
                .monospacedDigit()
        }
        .animation(.easeOut(duration: 0.2), value: model.hero)
        .accessibilityElement(children: .combine)
    }

    private func stillOpenBanner(_ app: AppUsage) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Theme.mustard)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(app.identity.name) is still open")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("It may be waiting for you to save something. Check the app first.")
                    .font(.callout)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 12)
            Button("Dismiss") { model.dismissStillOpen() }
            Button("Force Quit…") { isConfirmingForceQuit = true }
                .alert("Force quit \(app.identity.name)?", isPresented: $isConfirmingForceQuit) {
                    Button("Cancel", role: .cancel) {}
                    Button("Force Quit", role: .destructive) { Task { await model.forceQuit(app.identity) } }
                } message: {
                    Text("Any unsaved work in \(app.identity.name) will be lost.")
                }
        }
        .card()
    }

    private func closedBanner(_ app: AppUsage) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(Theme.sage)
            Text("\(app.identity.name) has closed")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .card()
    }

    private func processes(_ app: AppUsage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Processes").sectionHeading().padding(.bottom, 4)
            Text(processesCaption(app))
                .font(.callout)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            if model.rows.isEmpty {
                Hairline()
                Text("None of its processes are using the \(route.metric.phrase) right now.")
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.rows) { row in
                        Hairline()
                        ProcessRow(row: row)
                    }
                }
            }
            Hairline()
            if model.hiddenRowCount > 0 {
                Text("And \(UsageFormat.count(model.hiddenRowCount, "smaller process")) not shown")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.top, 8)
            }
        }
    }

    private func processesCaption(_ app: AppUsage) -> String {
        if app.identity.isSystem {
            return "Some system processes can't be read without administrator access. Their share is shown as one row, worked out from your Mac's total."
        }
        return "What makes up this app's \(route.metric.phrase) use. Processes with the same name are grouped."
    }

    private func destinations(_ app: AppUsage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Connects to").sectionHeading().padding(.bottom, 4)
            Text("Names come from reverse DNS. They can be missing, or show a delivery network instead of the real service.")
                .font(.callout)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            if app.destinations.isEmpty {
                Hairline()
                Text("No external connections seen since this window opened.")
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(app.destinations) { destination in
                        Hairline()
                        DestinationRow(destination: destination)
                    }
                }
            }
            Hairline()
        }
    }
}

private struct ProcessRow: View {
    let row: ProcessRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.name)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if row.count > 1 {
                    Text(UsageFormat.count(row.count, "process"))
                        .font(.callout)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                Text(row.value)
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            SegmentBar(
                segments: [.init(id: row.id, value: row.fraction, color: Theme.slate)],
                total: 1,
                height: 5
            )
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct DestinationRow: View {
    let destination: Destination

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.hostName ?? destination.address)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if destination.hostName != nil {
                    Text(destination.address)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 12)
            if destination.isActive {
                StatusBadge(title: "Now", symbol: "circle.fill", color: Theme.sage)
            } else {
                Text(destination.lastSeen, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
