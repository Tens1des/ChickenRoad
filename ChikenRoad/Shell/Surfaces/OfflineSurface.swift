import SwiftUI

/// Экран «нет интернета» с кнопкой повтора: тупика без выхода здесь быть не должно.
struct OfflineSurface: View {
    private let onRetry: () -> Void

    init(onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
    }

    var body: some View {
        CrossingScaffold(contentMaxWidth: 480) { layout in
            VStack(spacing: layout.usesSideBySideContent ? 20 : 24) {
                if layout.usesSideBySideContent {
                    HStack(spacing: 18) {
                        statusBadge(compact: true)
                        copy()
                    }
                } else {
                    VStack(spacing: 18) {
                        statusBadge(compact: false)
                        copy()
                    }
                }

                Button("Retry", action: onRetry)
                    .buttonStyle(CrossingPrimaryButtonStyle())
                    .frame(maxWidth: 360)
                    .accessibilityHint("Attempts to connect again")
            }
            .frame(maxWidth: layout.usesSideBySideContent ? 620 : .infinity)
        }
    }

    private func statusBadge(compact: Bool) -> some View {
        CrossingBadge(
            systemName: "wifi.slash",
            accessibilityLabel: "No internet connection",
            compact: compact
        )
    }

    private func copy() -> some View {
        VStack(spacing: 8) {
            CrossingHeadline(text: "NO INTERNET CONNECTION")

            CrossingBodyText(text: "Check your internet connection and try again.")
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}
