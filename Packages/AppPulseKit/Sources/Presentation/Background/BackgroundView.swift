import AppKit
import SwiftUI

/// Programs running with no window or Dock icon, and who signed them.
struct BackgroundView: View {
    @Bindable var model: BackgroundViewModel

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                MessageView(title: "Measuring…", message: "Your first figures will appear in a moment.")
            case .ready(let headline, let rows, let checkingCount):
                page(headline, rows, checkingCount: checkingCount)
            }
        }
        .paperBackground()
        .navigationTitle("Background")
        .quietToolbar()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Show", selection: $model.showsApplePrograms) {
                    Text("Not from Apple").tag(false)
                    Text("All").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private func page(_ headline: Headline, _ rows: [BackgroundRowModel], checkingCount: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    HeadlineView(headline: headline)
                    Text("Programs running with no window or Dock icon. “Unverified” means no identified developer signed it. That's a reason to look closer, not proof of harm.")
                        .font(.callout)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                list(rows, checkingCount: checkingCount)
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private func list(_ rows: [BackgroundRowModel], checkingCount: Int) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if checkingCount > 0 {
                Hairline()
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Checking who signed \(checkingCount == 1 ? "1 program" : "\(checkingCount) programs")…")
                        .foregroundStyle(Theme.inkSecondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 12)
            } else if rows.isEmpty {
                Hairline()
                Text("Every background program running now is from Apple.")
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.vertical, 12)
            }
            ForEach(rows) { row in
                Hairline()
                BackgroundRow(row: row)
            }
            Hairline()
        }
    }
}

private struct BackgroundRow: View {
    let row: BackgroundRowModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AppIconView(bundlePath: row.bundlePath, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.name)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if row.processCount > 1 {
                        Text(UsageFormat.count(row.processCount, "process"))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer(minLength: 12)
                    StatusBadge(title: row.badge.title, symbol: symbol, color: color)
                }
                Text(row.path)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: row.path)])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(row.path, forType: .string)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch row.badge.tone {
        case .concern: "exclamationmark.triangle.fill"
        case .caution: "questionmark.circle.fill"
        case .neutral: "checkmark.seal"
        case .trusted: "checkmark.seal.fill"
        }
    }

    private var color: Color {
        switch row.badge.tone {
        case .concern: Theme.rust
        case .caution: Theme.mustard
        case .neutral: Theme.stone
        case .trusted: Theme.sage
        }
    }
}
