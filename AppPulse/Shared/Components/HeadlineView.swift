import SwiftUI

/// The answer at the top of a page: one big figure, a phrase, and whole-Mac totals on the same baseline.
struct HeadlineView: View {
    let headline: Headline

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headline.value)
                    .font(Theme.display(54, weight: .light))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(headline.phrase)
                    .font(.title3)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 28) {
                ForEach(headline.totals, id: \.label) { figure in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(figure.value)
                            .font(Theme.display(26))
                            .foregroundStyle(Self.color(for: figure.tone))
                            .monospacedDigit()
                            .lineLimit(1)
                        Text(figure.label)
                            .font(.callout)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .fixedSize()
        }
        .animation(.easeOut(duration: 0.2), value: headline)
    }

    /// Rust for what's used, sage for what's left, ink for plain totals.
    /// Mixed toward ink less than `.readable`, so they still read as red and green. Sage needs more, as it is paler.
    static func color(for tone: TotalFigure.Tone) -> Color {
        switch tone {
        case .used: Theme.rust.mix(with: Theme.ink, by: 0.12)
        case .available: Theme.sage.mix(with: Theme.ink, by: 0.3)
        case .neutral: Theme.ink
        }
    }
}
