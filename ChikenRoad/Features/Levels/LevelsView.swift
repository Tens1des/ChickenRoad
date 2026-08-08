//
//  LevelsView.swift
//  ChikenRoad
//

import SwiftUI

struct LevelsView: View {
    var progress: GameProgress
    var onBack: () -> Void = {}
    var onSelectLevel: (Int) -> Void = { _ in }

    @State private var layoutSize: CGSize = .zero

    private let columnsCount = 3
    private let rowsCount = 5
    private let cellAspectRatio: CGFloat = 0.82

    private var horizontalPadding: CGFloat { max(layoutSize.width * 0.025, 8) }
    private var gridSpacing: CGFloat { max(layoutSize.width * 0.016, 5) }

    private var headerBlockHeight: CGFloat {
        let topButtonSize = max(layoutSize.width * 0.13, 44)
        let backButtonSize = max(layoutSize.width * 0.17, 52)
        let headerHeight = max(topButtonSize, backButtonSize)
        let titleHeight = max(layoutSize.width * 0.095, 30)
        let topPadding = layoutSize.height * 0.06 + 10
        return topPadding + headerHeight + titleHeight + 14
    }

    private var cellWidth: CGFloat {
        let widthLimit = max(
            layoutSize.width - horizontalPadding * 2 - gridSpacing * CGFloat(columnsCount - 1),
            240
        ) / CGFloat(columnsCount)

        let availableHeight = max(layoutSize.height - headerBlockHeight - 10, 200)
        let heightLimit = (availableHeight - gridSpacing * CGFloat(rowsCount - 1)) / CGFloat(rowsCount)
        let widthFromHeight = heightLimit / cellAspectRatio

        return min(widthLimit, widthFromHeight)
    }

    private var cellHeight: CGFloat { cellWidth * cellAspectRatio }

    var body: some View {
        ZStack {
            Image("BgLvl")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 6) {
                levelsHeader
                    .padding(.top, layoutSize.height * 0.06)

                levelsTitle

                levelsGrid
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .safeAreaPadding(.horizontal, horizontalPadding)
            .safeAreaPadding(.top, 6)
            .safeAreaPadding(.bottom, 10)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { _, newSize in
                layoutSize = newSize
            }
        }
    }

    private var levelsHeader: some View {
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

    private var levelsTitle: some View {
        Text("LEVELS")
            .font(.system(size: max(layoutSize.width * 0.095, 30), weight: .black, design: .rounded))
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

    private var levelsGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: gridSpacing),
            count: columnsCount
        )

        return LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(Level.allNumbers, id: \.self) { level in
                LevelCell(
                    state: progress.levelState(for: level),
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    onTap: { onSelectLevel(level) }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LevelCell: View {
    let state: LevelState
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(state.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: cellWidth, height: cellHeight)
        }
        .buttonStyle(.plain)
        .disabled(!state.isPlayable)
        .opacity(state == .locked ? 0.92 : 1)
    }
}

#Preview("Fresh progress") {
    LevelsView(progress: GameProgress())
}

#Preview("Mid progress") {
    let progress = GameProgress()
    progress.levelsCompleted = 4
    return LevelsView(progress: progress)
}
