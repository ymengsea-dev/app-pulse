import SwiftUI

struct OverviewView: View {
    let model: OverviewViewModel

    /// The biggest users get their own colours. The rest stay quiet.
    private static let colouredRows = 6

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                MessageView(title: "Measuring…", message: "Your first figures will appear in a moment.")
            case .message(let title, let message):
                MessageView(title: title, message: message)
            case .ready(let headline, let rows):
                page(headline, rows)
            }
        }
        .paperBackground()
        .navigationTitle(model.metric.title)
        .quietToolbar()
    }

    private func page(_ headline: Headline, _ rows: [AppRowModel]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header(headline, rows)
                list(rows)
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private func header(_ headline: Headline, _ rows: [AppRowModel]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HeadlineView(headline: headline)
            SegmentBar(segments: barSegments(rows), total: 1, height: 16)
        }
    }

    /// Everything past the coloured rows shares one segment, so tiny apps don't draw stripes.
    private func barSegments(_ rows: [AppRowModel]) -> [SegmentBar.Segment] {
        var segments = rows.prefix(Self.colouredRows).enumerated().map { index, row in
            SegmentBar.Segment(id: row.id, value: row.fraction, color: color(at: index))
        }
        let rest = rows.dropFirst(Self.colouredRows).reduce(0) { $0 + $1.fraction }
        segments.append(SegmentBar.Segment(id: "rest", value: rest, color: Theme.stone))
        return segments
    }

    private func list(_ rows: [AppRowModel]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                Hairline()
                Text(model.metric.idleListMessage)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.vertical, 12)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Hairline()
                AppRow(row: row, color: color(at: index), metric: model.metric) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        model.toggleExpanded(row.id)
                    }
                }
            }
            Hairline()
        }
    }

    private func color(at index: Int) -> Color {
        index < Self.colouredRows ? Theme.seriesColor(index) : Theme.stone
    }
}
