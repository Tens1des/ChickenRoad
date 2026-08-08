//
//  MainMenuView.swift
//  ChikenRoad
//

import SwiftUI

struct MainMenuView: View {
    var coins: Int = 0
    var onPlay: () -> Void = {}
    var onShop: () -> Void = {}
    var onAchievements: () -> Void = {}
    var onSettings: () -> Void = {}

    @State private var layoutSize: CGSize = .zero

    var body: some View {
        ZStack {
            Image("BgMain")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopHeaderBar(coins: coins, onSettings: onSettings)
                    .padding(.top, layoutSize.height * 0.10)

                Spacer(minLength: 0)

                SideButtonsBar(
                    onShop: onShop,
                    onAchievements: onAchievements,
                    layoutWidth: layoutSize.width
                )
            }
            .overlay(alignment: .bottom) {
                ImageButton(imageName: "PlayButton", action: onPlay)
                    .frame(width: layoutSize.width * 0.50)
                    .padding(.bottom, layoutSize.height * 0.01)
            }
            .safeAreaPadding(.horizontal, 16)
            .safeAreaPadding(.top, 10)
            .safeAreaPadding(.bottom, 40)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { _, newSize in
                layoutSize = newSize
            }
        }
    }
}

private struct TopHeaderBar: View {
    let coins: Int
    let onSettings: () -> Void

    @State private var containerWidth: CGFloat = 0

    var body: some View {
        let topButtonSize = max(containerWidth * 0.13, 44)
        let settingsButtonSize = max(containerWidth * 0.17, 52)
        let coinsPanelWidth = topButtonSize * 2.35

        HStack(alignment: .center, spacing: 12) {
            CoinsPanelView(amount: coins, height: topButtonSize)
                .frame(width: coinsPanelWidth)

            Spacer(minLength: 0)

            ImageButton(imageName: "SettingsButton", action: onSettings)
                .frame(width: settingsButtonSize, height: settingsButtonSize)
        }
        .frame(maxWidth: .infinity, minHeight: settingsButtonSize)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { _, newWidth in
            containerWidth = newWidth
        }
    }
}

private struct SideButtonsBar: View {
    var onShop: () -> Void
    var onAchievements: () -> Void
    let layoutWidth: CGFloat

    var body: some View {
        let sideButtonSize = max(layoutWidth * 0.21, 0)
        let sideButtonsLift = max(layoutWidth * 0.08, 0)

        HStack(alignment: .bottom, spacing: 0) {
            ImageButton(imageName: "ShopButton", action: onShop)
                .frame(width: sideButtonSize, height: sideButtonSize)

            Spacer()

            ImageButton(imageName: "AchivButton", action: onAchievements)
                .frame(width: sideButtonSize, height: sideButtonSize)
                .offset(y: -sideButtonSize * 0.10)
        }
        .padding(.bottom, sideButtonsLift)
    }
}

#Preview {
    MainMenuView(coins: 1250)
}
