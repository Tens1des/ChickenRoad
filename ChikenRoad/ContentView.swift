//
//  ContentView.swift
//  ChikenRoad
//
//  Created by dad on 06.08.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainMenuView(
            coins: 1250,
            onPlay: { /* TODO: переход в игру */ },
            onShop: { /* TODO: открыть магазин */ },
            onAchievements: { /* TODO: открыть достижения */ },
            onSettings: { /* TODO: открыть настройки */ }
        )
    }
}

#Preview {
    ContentView()
}
