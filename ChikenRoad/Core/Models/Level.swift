//
//  Level.swift
//  ChikenRoad
//

import Foundation

enum LevelState {
    case locked
    case current
    case completed

    var imageName: String {
        switch self {
        case .locked: "Lock"
        case .current: "Next"
        case .completed: "Unlock"
        }
    }

    var isPlayable: Bool {
        self != .locked
    }
}

enum Level {
    static let totalCount = 15

    static var allNumbers: [Int] {
        Array(1...totalCount)
    }
}

extension GameProgress {
    func levelState(for level: Int) -> LevelState {
        guard (1...Level.totalCount).contains(level) else { return .locked }

        if level <= levelsCompleted {
            return .completed
        }
        if level == levelsCompleted + 1 {
            return .current
        }
        return .locked
    }
}
