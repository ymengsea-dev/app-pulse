import SwiftUI

/// The one layout for every "nothing to show" state, so they all match.
struct MessageView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(Theme.pageTitle)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
