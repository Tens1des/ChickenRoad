//
//  AchievementsView.swift
//  ChikenRoad
//

import SwiftUI

private enum AppPalette {
    static let titleTop = Color(red: 1.0, green: 0.86, blue: 0.45)
    static let titleBottom = Color(red: 0.98, green: 0.62, blue: 0.12)
    static let titleShadow = Color(red: 0.45, green: 0.28, blue: 0.08)

    static let tabTop = Color(red: 0.58, green: 0.34, blue: 0.14)
    static let tabBottom = Color(red: 0.42, green: 0.24, blue: 0.08)

    static let cardTop = Color(red: 0.86, green: 0.62, blue: 0.34)
    static let cardMid = Color(red: 0.78, green: 0.48, blue: 0.22)
    static let cardBottom = Color(red: 0.62, green: 0.36, blue: 0.14)

    static let borderLight = Color(red: 0.98, green: 0.86, blue: 0.45)
    static let borderDark = Color(red: 0.72, green: 0.48, blue: 0.14)

    static let accentTop = Color(red: 1.0, green: 0.96, blue: 0.42)
    static let accentBottom = Color(red: 1.0, green: 0.78, blue: 0.12)

    static let slotTop = Color(red: 0.52, green: 0.32, blue: 0.14)
    static let slotBottom = Color(red: 0.38, green: 0.22, blue: 0.08)
}

struct AchievementsView: View {
    var progress: GameProgress
    var onBack: () -> Void = {}

    @State private var layoutSize: CGSize = .zero

    private var horizontalPadding: CGFloat { max(layoutSize.width * 0.05, 16) }
    private var cardSpacing: CGFloat { max(layoutSize.height * 0.018, 14) }

    var body: some View {
        ZStack {
            Image("BgAchiv")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                achievementsHeader
                    .padding(.top, layoutSize.height * 0.10)

                achievementsTitle
                    .padding(.top, layoutSize.height * 0.02)

                achievementsList
                    .padding(.top, layoutSize.height * 0.025)
            }
            .safeAreaPadding(.horizontal, horizontalPadding)
            .safeAreaPadding(.top, 10)
            .safeAreaPadding(.bottom, 24)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { _, newSize in
                layoutSize = newSize
            }
        }
    }

    private var achievementsHeader: some View {
        let topButtonSize = max(layoutSize.width * 0.13, 44)
        let backButtonSize = max(layoutSize.width * 0.17, 52)
        let coinsPanelWidth = topButtonSize * 2.35

        return HStack(alignment: .center, spacing: 12) {
            AchievementsCoinsPanelView(amount: progress.coins, height: topButtonSize)
                .frame(width: coinsPanelWidth)

            Spacer(minLength: 0)

            AchievementsImageButton(imageName: "SettingsButton", action: onBack)
                .frame(width: backButtonSize, height: backButtonSize)
        }
        .frame(maxWidth: .infinity)
    }

    private var achievementsTitle: some View {
        Text("ACHIEVEMENTS")
            .font(.system(size: max(layoutSize.width * 0.11, 34), weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [AppPalette.titleTop, AppPalette.titleBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: AppPalette.titleShadow, radius: 0, x: 0, y: 3)
            .shadow(color: AppPalette.titleShadow.opacity(0.75), radius: 0, x: 0, y: 5)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }

    private var achievementsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: cardSpacing) {
                ForEach(Achievement.catalog) { achievement in
                    AchievementCardView(
                        achievement: achievement,
                        isUnlocked: progress.isAchievementUnlocked(achievement),
                        layoutWidth: layoutSize.width - horizontalPadding * 2
                    )
                }
            }
            .padding(.bottom, cardSpacing)
        }
    }
}

private struct AchievementCardView: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let layoutWidth: CGFloat

    private var cardWidth: CGFloat { max(layoutWidth, 280) }
    private var cardHeight: CGFloat { cardWidth * 0.34 }
    private var tabHeight: CGFloat { cardHeight * 0.34 }
    private var iconSlotSize: CGFloat { cardHeight * 0.62 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AchievementTabShape()
                .fill(
                    LinearGradient(
                        colors: [AppPalette.tabTop, AppPalette.tabBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    AchievementTabShape()
                        .stroke(AppPalette.borderLight.opacity(0.35), lineWidth: 1)
                }
                .frame(width: cardWidth * 0.52, height: tabHeight)
                .overlay(alignment: .leading) {
                    Text(achievement.title)
                        .font(.system(size: tabHeight * 0.48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppPalette.accentTop, AppPalette.accentBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: AppPalette.titleShadow, radius: 0, x: 0, y: 1)
                        .padding(.leading, cardWidth * 0.04)
                        .padding(.trailing, cardWidth * 0.08)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

            ZStack {
                RoundedRectangle(cornerRadius: cardWidth * 0.045, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.cardTop, AppPalette.cardMid, AppPalette.cardBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: cardWidth * 0.04, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppPalette.borderLight, AppPalette.borderDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: cardWidth * 0.012
                    )
                    .padding(1)

                HStack(alignment: .center, spacing: cardWidth * 0.04) {
                    Text(achievement.description)
                        .font(.system(size: cardWidth * 0.042, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: AppPalette.titleShadow.opacity(0.85), radius: 0, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AchievementIconSlot(
                        systemName: achievement.iconSystemName,
                        isUnlocked: isUnlocked,
                        size: iconSlotSize
                    )
                }
                .padding(.horizontal, cardWidth * 0.045)
                .padding(.vertical, cardHeight * 0.12)
            }
            .frame(height: cardHeight)
            .shadow(color: AppPalette.tabBottom.opacity(0.45), radius: 8, y: 4)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        }
        .frame(width: cardWidth)
        .opacity(isUnlocked ? 1 : 0.78)
        .saturation(isUnlocked ? 1 : 0.72)
    }
}

private struct AchievementIconSlot: View {
    let systemName: String
    let isUnlocked: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppPalette.slotTop, AppPalette.slotBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .stroke(Color.black.opacity(0.22), lineWidth: 1.5)
                        .padding(size * 0.06)
                }

            if isUnlocked {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppPalette.accentTop, AppPalette.accentBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.28))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct AchievementTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let slant = rect.height * 0.55
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct AchievementsCoinsPanelView: View {
    let amount: Int
    let height: CGFloat

    private var cornerRadius: CGFloat { height * 0.3 }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image("IconMoney")
                .resizable()
                .scaledToFit()
                .frame(width: height * 0.82, height: height * 0.82)
                .offset(x: -2)

            Text(formattedAmount)
                .font(.system(size: height * 0.44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0.28, green: 0.12, blue: 0.04), radius: 0, x: 0, y: 2)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(height: height)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.18, blue: 0.1),
                                Color(red: 0.58, green: 0.1, blue: 0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.86, blue: 0.45),
                                Color(red: 0.72, green: 0.48, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: height * 0.07
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
    }
}

private struct AchievementsImageButton: View {
    let imageName: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .scaleEffect(isPressed ? 0.94 : 1)
                .animation(.easeOut(duration: 0.12), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    AchievementsView(progress: GameProgress.previewWithAchievements)
}
