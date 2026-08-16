//
//  ChikenRoadApp.swift
//  ChikenRoad
//

import SwiftUI

@main
struct ChikenRoadApp: App {
    @UIApplicationDelegateAdaptor(ShellSystemBridge.self) private var systemBridge

    var body: some Scene {
        WindowGroup {
            ShellScene {
                ContentView()
            }
        }
    }
}
