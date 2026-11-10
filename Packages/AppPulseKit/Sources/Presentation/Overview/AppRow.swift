import SwiftUI

/// An app in the overview list. Clicking it opens its processes in place. The app's page is one link further.
struct AppRow: View {
    let row: AppRowModel
    let color: Color
    let metric: UsageMetric
    let onToggle: () -> Void

    private var isExpanded: Bool { row.processes != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) { header }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Hides its processes" : "Shows its processes")
            if let processes = row.processes {
                breakdown(processes)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AppIconView(bundlePath: row.bundlePath, size: 32)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(row.name)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 12)
                    if let detail = row.detail {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(Theme.inkSecondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Text(row.value)
                        .font(Theme.display(20))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                SegmentBar(
                    segments: [.init(id: row.id, value: row.fraction, color: color)],
                    total: 1,
                    height: 5
                )
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Indented under the app's name, so it reads as part of this row.
    private func breakdown(_ processes: ProcessBreakdown.Result) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if processes.rows.isEmpty {
                Text("None of its processes are using the \(metric.phrase) right now.")
                    .font(.callout)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.vertical, 6)
            }
            ForEach(processes.rows) { process in
                SubprocessRow(row: process, color: color)
            }
            HStack(spacing: 12) {
                if processes.hiddenCount > 0 {
                    Text("And \(UsageFormat.count(processes.hiddenCount, "smaller process"))")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                NavigationLink(value: AppRoute(appID: row.id, metric: metric)) {
                    Text("View details")
                }
                .buttonStyle(.link)
            }
            .padding(.top, 6)
        }
        .padding(.leading, 46)
        .padding(.trailing, 22)
        .padding(.bottom, 12)
    }
}

private struct SubprocessRow: View {
    let row: ProcessRowModel
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.name)
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if row.count > 1 {
                    Text(UsageFormat.count(row.count, "process"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                Text(row.value)
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            SegmentBar(
                segments: [.init(id: row.id, value: row.fraction, color: color.mix(with: Theme.paper, by: 0.32))],
                total: 1,
                height: 3
            )
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
