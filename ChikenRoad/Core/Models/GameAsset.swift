//
//  GameAsset.swift
//  ChikenRoad
//

import Foundation

enum GameAsset {
    static let roadBackground = "openart-image_uAl6oUCL_1740656801526_raw"

    static let pepper = "Rectangle"
    static let egg = "Rectangle (1)"
    static let slime = "Rectangle (2)"
    static let barrel = "Rectangle (3)"
    static let cactus = "Rectangle (4)"

    static func playerSprite(for skinId: String) -> String {
        switch skinId {
        case "Skin2": "Rectangle (5)"
        case "Skin3": "Rectangle (6)"
        case "Skin4": "Rectangle (7)"
        case "Skin5": "Rectangle (9)"
        default: "Rectangle (8)"
        }
    }
}
