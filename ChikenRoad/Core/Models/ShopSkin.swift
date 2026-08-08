//
//  ShopSkin.swift
//  ChikenRoad
//

import Foundation

struct ShopSkin: Identifiable, Equatable {
    let id: String
    let imageName: String
    let price: Int

    static let catalog: [ShopSkin] = [
        ShopSkin(id: "Skin1", imageName: "Skin1", price: 0),
        ShopSkin(id: "Skin2", imageName: "Skin2", price: 500),
        ShopSkin(id: "Skin3", imageName: "Skin3", price: 1_000),
        ShopSkin(id: "Skin4", imageName: "Skin4", price: 2_500),
        ShopSkin(id: "Skin5", imageName: "Skin5", price: 5_000)
    ]
}
