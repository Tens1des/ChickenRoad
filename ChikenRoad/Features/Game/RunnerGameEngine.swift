//
//  RunnerGameEngine.swift
//  ChikenRoad
//

import Foundation
import Observation

enum RunnerPhase: Equatable {
    case ready
    case playing
    case paused
    case gameOver
    case levelComplete
}

enum RunnerLane: Int, CaseIterable {
    case left = 0
    case right = 1
}

enum RunnerCollectible: CaseIterable {
    case egg
    case pepper
    case barrel
    case cactus
    case slime

    var imageName: String {
        switch self {
        case .egg: GameAsset.egg
        case .pepper: GameAsset.pepper
        case .barrel: GameAsset.barrel
        case .cactus: GameAsset.cactus
        case .slime: GameAsset.slime
        }
    }

    var isDeadly: Bool {
        self == .cactus || self == .slime
    }
}

enum BarrelOutcome: Equatable {
    case coins(Int)
    case speedBoost
    case slowDown
    case coinLoss(Int)

    var message: String {
        switch self {
        case .coins(let amount): "+\(amount) coins!"
        case .speedBoost: "Speed boost!"
        case .slowDown: "Slowed down..."
        case .coinLoss(let amount): "-\(amount) coins"
        }
    }
}

struct RunnerEntity: Identifiable, Equatable {
    let id: UUID
    let lane: RunnerLane
    let kind: RunnerCollectible
    var normalizedY: CGFloat
    let spawnTime: TimeInterval
}

struct FloatingLabel: Identifiable, Equatable {
    let id: UUID
    let text: String
    let normalizedX: CGFloat
    var normalizedY: CGFloat
    var age: TimeInterval
    let isCoin: Bool
}

@Observable
final class RunnerGameEngine {
    let level: Int
    let skinId: String

    private(set) var phase: RunnerPhase = .ready
    private(set) var playerLane: RunnerLane = .left
    private(set) var entities: [RunnerEntity] = []
    private(set) var distance: Int = 0
    private(set) var sessionCoins: Int = 0
    private(set) var speedMultiplier: CGFloat = 1
    private(set) var roadScroll: CGFloat = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var floatingLabels: [FloatingLabel] = []
    private(set) var screenShake: CGFloat = 0
    private(set) var flashOpacity: CGFloat = 0
    private(set) var flashIsRed: Bool = false
    private(set) var pepperSparkPhase: CGFloat = 0
    private(set) var playerSquashX: CGFloat = 1
    private(set) var playerSquashY: CGFloat = 1
    private(set) var playerHitActive: Bool = false
    private(set) var statusMessage: String?
    private(set) var didCompleteTargetLevel = false

    private var lastUpdateDate: Date?
    private var spawnAccumulator: TimeInterval = 0
    private var fractionalDistance: Double = 0
    private var hasReachedTarget = false
    private var pendingGameOver = false
    private var freezeUntil: Date?
    private var pepperSparksUntil: Date?
    private var flashUntil: Date?
    private var laneBumpUntil: Date?
    private var messageResetWorkItem: DispatchWorkItem?
    private var speedBoostUntil: Date?
    private var slowUntil: Date?

    private let spawnStartDelay: TimeInterval = 1.8
    private let paceRampDuration: TimeInterval = 55

    var targetDistance: Int { level * 250 + 150 }
    var playerImageName: String { GameAsset.playerSprite(for: skinId) }

    private var paceProgress: CGFloat {
        min(CGFloat(elapsedTime / paceRampDuration), 1)
    }

    /// Road scroll and item fall speed — ramps up over time.
    var scrollSpeed: CGFloat {
        let start = 0.34 + CGFloat(level - 1) * 0.022
        let end = start * 1.85
        let ramped = start + (end - start) * paceProgress
        return ramped * speedMultiplier
    }

    /// Meters tick slower and also accelerate toward end of level.
    private var metersPerSecond: Double {
        let start = 3.6 + Double(level - 1) * 0.3
        let end = start * 1.55
        return start + (end - start) * Double(paceProgress)
    }

    var currentSpeed: CGFloat { scrollSpeed }

    init(level: Int, skinId: String) {
        self.level = level
        self.skinId = skinId
    }

    func startIfNeeded() {
        guard phase == .ready else { return }
        phase = .playing
        lastUpdateDate = nil
        elapsedTime = 0
        roadScroll = 0
        hasReachedTarget = false
        spawnAccumulator = 0
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        lastUpdateDate = nil
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        lastUpdateDate = nil
    }

    func moveLeft() {
        guard phase == .playing || phase == .ready else { return }
        guard playerLane != .left else { return }
        playerLane = .left
        triggerLaneChangeSquash()
    }

    func moveRight() {
        guard phase == .playing || phase == .ready else { return }
        guard playerLane != .right else { return }
        playerLane = .right
        triggerLaneChangeSquash()
    }

    func update(at date: Date) {
        guard phase == .playing || pendingGameOver else { return }

        if pendingGameOver {
            if let freezeUntil, date < freezeUntil {
                refreshVisuals(delta: 1.0 / 60.0, date: date)
                return
            }
            phase = .gameOver
            pendingGameOver = false
            self.freezeUntil = nil
            lastUpdateDate = nil
            return
        }

        refreshSpeedEffects(at: date)

        guard let lastUpdateDate else {
            self.lastUpdateDate = date
            return
        }

        let delta = min(date.timeIntervalSince(lastUpdateDate), 1.0 / 30.0)
        self.lastUpdateDate = date
        elapsedTime += delta

        refreshVisuals(delta: delta, date: date)

        let scrollStep = scrollSpeed * CGFloat(delta)
        roadScroll += scrollStep

        for index in entities.indices {
            entities[index].normalizedY += scrollStep
        }

        entities.removeAll { $0.normalizedY > 1.15 }

        if !hasReachedTarget {
            if elapsedTime >= spawnStartDelay {
                spawnAccumulator += delta
                let spawnInterval = max(0.95 - elapsedTime * 0.006, 0.48)
                while spawnAccumulator >= spawnInterval {
                    spawnAccumulator -= spawnInterval
                    spawnEntity()
                }
            }

            fractionalDistance += delta * metersPerSecond
            distance = min(Int(fractionalDistance), targetDistance)
            if distance >= targetDistance {
                hasReachedTarget = true
                distance = targetDistance
            }
        }

        resolveCollisions()

        if hasReachedTarget && entities.isEmpty {
            finishLevel()
        }
    }

    private func refreshVisuals(delta: TimeInterval, date: Date) {
        for index in floatingLabels.indices {
            floatingLabels[index].age += delta
            floatingLabels[index].normalizedY -= CGFloat(delta) * 0.22
        }
        floatingLabels.removeAll { $0.age > 0.9 }

        screenShake = max(0, screenShake - delta * 14)

        if let flashUntil {
            if date < flashUntil {
                let remaining = flashUntil.timeIntervalSince(date)
                flashOpacity = min(0.55, CGFloat(remaining * 2.5))
            } else {
                self.flashUntil = nil
                flashOpacity = 0
            }
        } else {
            flashOpacity = 0
        }

        if let pepperSparksUntil {
            if date < pepperSparksUntil {
                let elapsed = pepperSparksUntil.timeIntervalSince(date)
                pepperSparkPhase = 1 - CGFloat(elapsed / 0.45)
            } else {
                self.pepperSparksUntil = nil
                pepperSparkPhase = 0
            }
        }

        if let laneBumpUntil, date >= laneBumpUntil {
            self.laneBumpUntil = nil
            playerSquashX = 1
            playerSquashY = 1
        } else if laneBumpUntil == nil && !playerHitActive {
            let bob = sin(elapsedTime * 11) * 0.035
            playerSquashX = 1 + bob
            playerSquashY = 1 - bob * 0.5
        }

        if playerHitActive {
            playerSquashX = 0.82
            playerSquashY = 1.18
        }
    }

    private func triggerLaneChangeSquash() {
        playerSquashX = 1.18
        playerSquashY = 0.86
        laneBumpUntil = Date().addingTimeInterval(0.12)
    }

    private func spawnFloatingLabel(_ text: String, isCoin: Bool) {
        let x: CGFloat = playerLane == .left ? 0.38 : 0.62
        floatingLabels.append(
            FloatingLabel(
                id: UUID(),
                text: text,
                normalizedX: x,
                normalizedY: 0.72,
                age: 0,
                isCoin: isCoin
            )
        )
    }

    private func triggerPepperJuice() {
        flashIsRed = true
        flashUntil = Date().addingTimeInterval(0.22)
        pepperSparksUntil = Date().addingTimeInterval(0.45)
        pepperSparkPhase = 0
    }

    private func triggerBarrelJuice() {
        screenShake = 10
    }

    private func triggerDeadlyJuice() {
        flashIsRed = true
        flashUntil = Date().addingTimeInterval(0.45)
        flashOpacity = 0.55
        playerHitActive = true
        screenShake = 14
        pendingGameOver = true
        freezeUntil = Date().addingTimeInterval(0.45)
        lastUpdateDate = nil
    }

    private func refreshSpeedEffects(at date: Date) {
        if let speedBoostUntil, date >= speedBoostUntil {
            self.speedBoostUntil = nil
            if slowUntil == nil || date >= slowUntil! {
                speedMultiplier = 1
            }
        }

        if let slowUntil, date >= slowUntil {
            self.slowUntil = nil
            if speedBoostUntil == nil || date >= speedBoostUntil! {
                speedMultiplier = 1
            }
        }
    }

    private func spawnEntity() {
        let playableLanes = RunnerLane.allCases
        let occupiedLanes = Set(entities.filter { $0.normalizedY < 0.2 }.map(\.lane))
        let freeLanes = playableLanes.filter { !occupiedLanes.contains($0) }
        guard let lane = freeLanes.randomElement() ?? playableLanes.randomElement() else { return }

        let kind = weightedRandomCollectible()
        entities.append(
            RunnerEntity(
                id: UUID(),
                lane: lane,
                kind: kind,
                normalizedY: -0.12,
                spawnTime: elapsedTime
            )
        )
    }

    private func weightedRandomCollectible() -> RunnerCollectible {
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<34: return .egg
        case 34..<48: return .pepper
        case 48..<58: return .barrel
        case 58..<80: return .cactus
        default: return .slime
        }
    }

    private func resolveCollisions() {
        let hitZone: ClosedRange<CGFloat> = 0.74...0.88
        let hits = entities.filter { $0.lane == playerLane && hitZone.contains($0.normalizedY) }
        guard !hits.isEmpty else { return }

        for hit in hits {
            entities.removeAll { $0.id == hit.id }
            apply(hit.kind)
            if phase != .playing { return }
        }
    }

    private func apply(_ kind: RunnerCollectible) {
        switch kind {
        case .egg:
            sessionCoins += 15
            spawnFloatingLabel("+15", isCoin: true)
            showMessage("+15")

        case .pepper:
            applySpeedBoost(duration: 3.5, multiplier: 1.55)
            triggerPepperJuice()
            showMessage("Pepper! Speed up!")

        case .barrel:
            triggerBarrelJuice()
            applyBarrelEffect()

        case .cactus, .slime:
            triggerDeadlyJuice()
        }
    }

    private func applyBarrelEffect() {
        let roll = Int.random(in: 0..<100)
        let outcome: BarrelOutcome

        switch roll {
        case 0..<30:
            let bonus = Int.random(in: 25...60)
            sessionCoins += bonus
            outcome = .coins(bonus)
            spawnFloatingLabel("+\(bonus)", isCoin: true)
        case 30..<55:
            applySpeedBoost(duration: 2.5, multiplier: 1.4)
            outcome = .speedBoost
        case 55..<75:
            applySlow(duration: 2.0, multiplier: 0.65)
            outcome = .slowDown
        default:
            let penalty = min(sessionCoins, Int.random(in: 10...35))
            sessionCoins -= penalty
            outcome = .coinLoss(penalty)
        }

        showMessage(outcome.message)
    }

    private func applySpeedBoost(duration: TimeInterval, multiplier: CGFloat) {
        slowUntil = nil
        speedMultiplier = multiplier
        speedBoostUntil = Date().addingTimeInterval(duration)
    }

    private func applySlow(duration: TimeInterval, multiplier: CGFloat) {
        speedBoostUntil = nil
        speedMultiplier = multiplier
        slowUntil = Date().addingTimeInterval(duration)
    }

    private func finishLevel() {
        phase = .levelComplete
        lastUpdateDate = nil
        didCompleteTargetLevel = true
    }

    private func showMessage(_ text: String) {
        statusMessage = text
        messageResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.statusMessage = nil
        }
        messageResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    func resetRun() {
        entities = []
        distance = 0
        fractionalDistance = 0
        sessionCoins = 0
        speedMultiplier = 1
        roadScroll = 0
        playerLane = .left
        spawnAccumulator = 0
        elapsedTime = 0
        hasReachedTarget = false
        floatingLabels = []
        screenShake = 0
        flashOpacity = 0
        flashIsRed = false
        pepperSparkPhase = 0
        playerSquashX = 1
        playerSquashY = 1
        playerHitActive = false
        pendingGameOver = false
        freezeUntil = nil
        pepperSparksUntil = nil
        flashUntil = nil
        laneBumpUntil = nil
        speedBoostUntil = nil
        slowUntil = nil
        statusMessage = nil
        didCompleteTargetLevel = false
        phase = .ready
        lastUpdateDate = nil
    }
}
