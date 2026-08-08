//
//  ContentView.swift
//  ChikenRoad
//

import SwiftUI

struct ContentView: View {
    @State private var screen: AppScreen = .mainMenu
    @State private var progress = GameProgress()

    var body: some View {
        Group {
            switch screen {
            case .mainMenu:
                MainMenuView(
                    coins: progress.coins,
                    onPlay: { screen = .levels },
                    onShop: { screen = .shop },
                    onAchievements: { screen = .achievements },
                    onSettings: { screen = .settings }
                )
                .transition(.opacity)

            case .levels:
                LevelsView(
                    progress: progress,
                    onBack: { screen = .mainMenu },
                    onSelectLevel: { level in screen = .game(level: level) }
                )
                .transition(.opacity)

            case .game(let level):
                GameView(
                    level: level,
                    progress: progress,
                    onExit: { screen = .levels }
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
