import SwiftUI

/// Кастомный запрос уведомлений перед переходом в витрину.
///
/// Тексты кнопок дословные — они часть контракта приёмки, не копирайтинг.
///
/// Горизонталь — единственный экран с разведёнными колонками: текст слева,
/// кнопки справа. Так снято с референсов заказчика.
struct ConsentSurface: View {
    private let privacyPolicyURL: URL?
    private let onAccept: () -> Void
    private let onSkip: () -> Void

    init(
        privacyPolicyURL: URL?,
        onAccept: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.privacyPolicyURL = privacyPolicyURL
        self.onAccept = onAccept
        self.onSkip = onSkip
    }

    var body: some View {
        CrossingScaffold(contentMaxWidth: 500) { layout in
            if layout.usesSideBySideContent {
                HStack(alignment: .center, spacing: 36) {
                    copy(alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    actions(alignment: .center)
                        .frame(width: 320)
                }
            } else {
                VStack(spacing: 24) {
                    copy(alignment: .center)
                    actions(alignment: .center)
                }
            }
        }
    }

    private func copy(alignment: TextAlignment) -> some View {
        let horizontal: HorizontalAlignment = alignment == .leading ? .leading : .center

        return VStack(alignment: horizontal, spacing: 12) {
            CrossingHeadline(text: "DON'T MISS YOUR BONUSES")

            CrossingBodyText(
                text: "Turn on notifications for rewards, new levels and special offers. You can change this anytime in Settings."
            )
        }
        .multilineTextAlignment(alignment)
        .accessibilityElement(children: .combine)
    }

    private func actions(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 12) {
            Button("Yes, I Want Bonuses!", action: onAccept)
                .buttonStyle(CrossingPrimaryButtonStyle())
                .accessibilityHint("Continues to the system notification permission prompt")

            Button("Skip", action: onSkip)
                .buttonStyle(CrossingSecondaryButtonStyle())
                .accessibilityHint("Continues without enabling notifications")

            if let privacyPolicyURL {
                CrossingPolicyLink(destination: privacyPolicyURL)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }
}
