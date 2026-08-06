//
//  GameProgress.swift
//  ChikenRoad
//

import Foundation
import Observation

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

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let iconSystemName: String

    static let catalog: [Achievement] = [
        Achievement(
            id: "firstCrossing",
            title: "First Crossing",
            description: "Cross The Road For The First Time",
            iconSystemName: "figure.walk"
        ),
        Achievement(
            id: "noFear",
            title: "No Fear",
            description: "Cross 3 Roads In A Row Without Getting Hit",
            iconSystemName: "shield.fill"
        ),
        Achievement(
            id: "coinStash",
            title: "Coin Stash",
            description: "Save Up 2 000 Coins",
            iconSystemName: "dollarsign.circle.fill"
        ),
        Achievement(
            id: "freshLook",
            title: "Fresh Look",
            description: "Buy A New Skin For Your Hen",
            iconSystemName: "sparkles"
        ),
        Achievement(
            id: "roadLegend",
            title: "Road Legend",
            description: "Complete 10 Levels",
            iconSystemName: "flag.checkered"
        )
    ]
}

@Observable
final class GameProgress {
    private enum StorageKey {
        static let coins = "playerCoins"
        static let selectedSkinId = "selectedSkinId"
        static let purchasedSkins = "purchasedSkinIds"
        static let unlockedAchievements = "unlockedAchievementIds"
        static let levelsCompleted = "levelsCompleted"
        static let roadsCrossed = "roadsCrossed"
        static let flawlessCrossings = "flawlessCrossings"
        static let peakCoins = "peakCoins"
    }

    var coins: Int {
        didSet {
            UserDefaults.standard.set(coins, forKey: StorageKey.coins)
            if coins > peakCoins {
                peakCoins = coins
            }
            refreshAchievements()
        }
    }

    var selectedSkinId: String {
        didSet { UserDefaults.standard.set(selectedSkinId, forKey: StorageKey.selectedSkinId) }
    }

    private(set) var purchasedSkinIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(purchasedSkinIds), forKey: StorageKey.purchasedSkins)
            refreshAchievements()
        }
    }

    private(set) var unlockedAchievementIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(unlockedAchievementIds), forKey: StorageKey.unlockedAchievements)
        }
    }

    var levelsCompleted: Int {
        didSet {
            UserDefaults.standard.set(levelsCompleted, forKey: StorageKey.levelsCompleted)
            refreshAchievements()
        }
    }

    var roadsCrossed: Int {
        didSet {
            UserDefaults.standard.set(roadsCrossed, forKey: StorageKey.roadsCrossed)
            refreshAchievements()
        }
    }

    var flawlessCrossings: Int {
        didSet {
            UserDefaults.standard.set(flawlessCrossings, forKey: StorageKey.flawlessCrossings)
            refreshAchievements()
        }
    }

    var peakCoins: Int {
        didSet {
            UserDefaults.standard.set(peakCoins, forKey: StorageKey.peakCoins)
            refreshAchievements()
        }
    }

    init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: StorageKey.coins) == nil {
            defaults.set(1_250, forKey: StorageKey.coins)
        }
        if defaults.string(forKey: StorageKey.selectedSkinId) == nil {
            defaults.set("Skin1", forKey: StorageKey.selectedSkinId)
        }
        if defaults.stringArray(forKey: StorageKey.purchasedSkins) == nil {
            defaults.set(["Skin1"], forKey: StorageKey.purchasedSkins)
        }

        let loadedCoins = defaults.integer(forKey: StorageKey.coins)

        coins = loadedCoins
        selectedSkinId = defaults.string(forKey: StorageKey.selectedSkinId) ?? "Skin1"
        purchasedSkinIds = Set(defaults.stringArray(forKey: StorageKey.purchasedSkins) ?? ["Skin1"])
        unlockedAchievementIds = Set(defaults.stringArray(forKey: StorageKey.unlockedAchievements) ?? [])
        levelsCompleted = defaults.integer(forKey: StorageKey.levelsCompleted)
        roadsCrossed = defaults.integer(forKey: StorageKey.roadsCrossed)
        flawlessCrossings = defaults.integer(forKey: StorageKey.flawlessCrossings)
        peakCoins = max(defaults.integer(forKey: StorageKey.peakCoins), loadedCoins)

        refreshAchievements()
    }

    static var previewWithAchievements: GameProgress {
        let progress = GameProgress()
        progress.unlockedAchievementIds = ["firstCrossing", "freshLook"]
        return progress
    }

    func isOwned(_ skin: ShopSkin) -> Bool {
        purchasedSkinIds.contains(skin.id)
    }

    func isSelected(_ skin: ShopSkin) -> Bool {
        selectedSkinId == skin.id
    }

    @discardableResult
    func purchase(_ skin: ShopSkin) -> Bool {
        guard !isOwned(skin) else { return select(skin) }
        guard skin.price == 0 || coins >= skin.price else { return false }

        if skin.price > 0 {
            coins -= skin.price
        }

        purchasedSkinIds.insert(skin.id)
        selectedSkinId = skin.id
        return true
    }

    @discardableResult
    func select(_ skin: ShopSkin) -> Bool {
        guard isOwned(skin) else { return false }
        selectedSkinId = skin.id
        return true
    }

    func handleSkinTap(_ skin: ShopSkin) {
        if isOwned(skin) {
            select(skin)
        } else {
            purchase(skin)
        }
    }

    func isAchievementUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAchievementIds.contains(achievement.id)
    }

    func recordRoadCrossed(flawless: Bool) {
        roadsCrossed += 1
        if flawless {
            flawlessCrossings += 1
        } else {
            flawlessCrossings = 0
        }
    }

    func recordLevelCompleted() {
        levelsCompleted += 1
    }

    func addCoins(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
    }

    private func refreshAchievements() {
        var updated = unlockedAchievementIds

        if roadsCrossed >= 1 {
            updated.insert("firstCrossing")
        }
        if flawlessCrossings >= 3 {
            updated.insert("noFear")
        }
        if peakCoins >= 2_000 {
            updated.insert("coinStash")
        }
        if purchasedSkinIds.count > 1 {
            updated.insert("freshLook")
        }
        if levelsCompleted >= 10 {
            updated.insert("roadLegend")
        }

        unlockedAchievementIds = updated
    }
}
