//
//  Achievement.swift
//  ChikenRoad
//

import Foundation

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
