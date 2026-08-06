//
//  ContentView.swift
//  ChikenRoad
//
//  Created by dad on 06.08.2026.
//

import SwiftUI

private enum AppScreen {
    case mainMenu
    case shop
    case achievements
    case settings
}

struct ContentView: View {
    @State private var screen: AppScreen = .mainMenu
    @State private var progress = GameProgress()

    var body: some View {
        Group {
            switch screen {
            case .mainMenu:
                MainMenuView(
                    coins: progress.coins,
                    onPlay: { /* TODO: переход в игру */ },
                    onShop: { screen = .shop },
                    onAchievements: { screen = .achievements },
                    onSettings: { screen = .settings }
                )
                .transition(.opacity)

            case .shop:
                ShopView(
                    progress: progress,
                    onBack: { screen = .mainMenu }
                )
                .transition(.opacity)

            case .achievements:
                AchievementsView(
                    progress: progress,
                    onBack: { screen = .mainMenu }
                )
                .transition(.opacity)

            case .settings:
                SettingsView(onBack: { screen = .mainMenu })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
    }
}

#Preview {
    ContentView()
}
