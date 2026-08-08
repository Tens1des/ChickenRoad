//
//  AchievementsView.swift
//  ChikenRoad
//

import SwiftUI

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
            CoinsPanelView(amount: progress.coins, height: topButtonSize)
                .frame(width: coinsPanelWidth)

            Spacer(minLength: 0)

            ImageButton(imageName: "SettingsButton", action: onBack)
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

#Preview {
    AchievementsView(progress: GameProgress.previewWithAchievements)
}
