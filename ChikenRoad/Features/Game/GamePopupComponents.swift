//
//  GamePopupComponents.swift
//  ChikenRoad
//

import SwiftUI

enum GamePopupKind {
    case start
    case pause
    case gameOver
    case levelComplete
}

struct GamePopupBackdrop: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.45)
        }
        .ignoresSafeArea()
    }
}

struct GamePopupCard<Content: View>: View {
    let kind: GamePopupKind
    @ViewBuilder var content: () -> Content

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            popupHeader

            content()
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: 320)
        .background { cardBackground }
        .overlay { cardBorder }
        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var popupHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: headerColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 74)
                .padding(.horizontal, 14)
                .padding(.top, 14)

            HStack(spacing: 10) {
                headerIcon
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

                Text(headerTitle)
                    .font(.system(size: headerTitleSize, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 2)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 12)
    }

    private var headerColors: [Color] {
        switch kind {
        case .start:
            [Color(red: 0.22, green: 0.52, blue: 0.92), Color(red: 0.12, green: 0.32, blue: 0.72)]
        case .pause:
            [Color(red: 0.52, green: 0.34, blue: 0.14), Color(red: 0.38, green: 0.22, blue: 0.08)]
        case .gameOver:
            [Color(red: 0.72, green: 0.16, blue: 0.14), Color(red: 0.48, green: 0.08, blue: 0.1)]
        case .levelComplete:
            [Color(red: 0.22, green: 0.62, blue: 0.18), Color(red: 0.12, green: 0.42, blue: 0.1)]
        }
    }

    @ViewBuilder
    private var headerIcon: some View {
        switch kind {
        case .start: Image(systemName: "figure.run")
        case .pause: Image(systemName: "pause.fill")
        case .gameOver: Image(systemName: "xmark.octagon.fill")
        case .levelComplete: Image(systemName: "flag.checkered")
        }
    }

    private var headerTitle: String {
        switch kind {
        case .start: "TAP TO RUN"
        case .pause: "PAUSE"
        case .gameOver: "GAME OVER"
        case .levelComplete: "LEVEL CLEAR!"
        }
    }

    private var headerTitleSize: CGFloat {
        kind == .start ? 26 : 24
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.78, blue: 0.52),
                        Color(red: 0.72, green: 0.48, blue: 0.24),
                        Color(red: 0.58, green: 0.36, blue: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [AppPalette.borderLight, AppPalette.borderDark, AppPalette.borderLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 4
            )
    }
}

struct GamePopupStatRow: View {
    let iconName: String
    let label: String
    let value: String
    var isAssetIcon: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isAssetIcon {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .frame(width: 28, height: 28)
            .foregroundStyle(AppPalette.titleBottom)

            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.32, green: 0.18, blue: 0.08))

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.12, blue: 0.04))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                }
        }
    }
}

struct GamePopupButton: View {
    let title: String
    var style: Style = .primary
    let action: () -> Void

    enum Style {
        case primary
        case secondary
        case danger
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background { buttonBackground }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(style == .secondary ? 0.22 : 0.35), lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
        }
        .buttonStyle(GamePopupPressStyle())
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.34, green: 0.78, blue: 0.22),
                            Color(red: 0.18, green: 0.58, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        case .secondary:
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.58, green: 0.36, blue: 0.16),
                            Color(red: 0.42, green: 0.24, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        case .danger:
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.22, blue: 0.16),
                            Color(red: 0.62, green: 0.12, blue: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

private struct GamePopupPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GameToastBanner: View {
    let message: String

    @State private var appeared = false

    var body: some View {
        Text(message)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.52, green: 0.32, blue: 0.14),
                                Color(red: 0.38, green: 0.22, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppPalette.borderLight, AppPalette.borderDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    }
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
                    appeared = true
                }
            }
    }
}

struct GameStartPopup: View {
    var onStart: () -> Void

    var body: some View {
        GamePopupCard(kind: .start) {
            VStack(spacing: 14) {
                Text("Swipe left or right to change lane")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.06))
                    .multilineTextAlignment(.center)

                GamePopupButton(title: "START", action: onStart)
            }
        }
    }
}

struct GamePausePopup: View {
    var onResume: () -> Void
    var onExit: () -> Void

    var body: some View {
        GamePopupCard(kind: .pause) {
            VStack(spacing: 12) {
                Text("Run is paused")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.06))

                GamePopupButton(title: "RESUME", action: onResume)
                GamePopupButton(title: "EXIT", style: .secondary, action: onExit)
            }
        }
    }
}

struct GameEndPopup: View {
    let kind: GamePopupKind
    let sessionCoins: Int
    let distance: Int
    var secondaryTitle: String = "LEVELS"
    var onPrimary: () -> Void
    var onSecondary: () -> Void

    var body: some View {
        GamePopupCard(kind: kind) {
            VStack(spacing: 12) {
                if kind == .levelComplete {
                    Text("Great run!")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.06))
                } else {
                    Text("Try again!")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.06))
                }

                GamePopupStatRow(
                    iconName: "IconMoney",
                    label: "Coins",
                    value: "+\(sessionCoins)",
                    isAssetIcon: true
                )

                if kind == .levelComplete {
                    GamePopupStatRow(
                        iconName: "figure.run",
                        label: "Distance",
                        value: "\(distance)m"
                    )
                }

                GamePopupButton(
                    title: kind == .levelComplete ? "AGAIN" : "TRY AGAIN",
                    action: onPrimary
                )

                GamePopupButton(
                    title: secondaryTitle,
                    style: .secondary,
                    action: onSecondary
                )
            }
        }
    }
}

#Preview("Start") {
    ZStack {
        Color.gray.ignoresSafeArea()
        GameStartPopup(onStart: {})
    }
}

#Preview("End") {
    ZStack {
        Color.gray.ignoresSafeArea()
        GameEndPopup(
            kind: .levelComplete,
            sessionCoins: 120,
            distance: 400,
            onPrimary: {},
            onSecondary: {}
        )
    }
}
