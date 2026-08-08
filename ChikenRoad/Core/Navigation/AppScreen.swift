//
//  AppScreen.swift
//  ChikenRoad
//

import Foundation

enum AppScreen: Equatable {
    case mainMenu
    case levels
    case game(level: Int)
    case shop
    case achievements
    case settings
}
