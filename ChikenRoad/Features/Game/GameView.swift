//
//  GameView.swift
//  ChikenRoad
//

import SwiftUI

struct GameView: View {
    let level: Int
    var progress: GameProgress
    var onExit: () -> Void = {}

    @State private var engine: RunnerGameEngine
    @State private var didApplyRewards = false

    init(level: Int, progress: GameProgress, onExit: @escaping () -> Void = {}) {
        self.level = level
        self.progress = progress
        self.onExit = onExit
        _engine = State(
            initialValue: RunnerGameEngine(
                level: level,
                skinId: progress.selectedSkinId
            )
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            gameContent(tick: timeline.date)
        }
        .onChange(of: engine.phase) { _, newPhase in
            applyRewardsIfNeeded(for: newPhase)
        }
    }

    @ViewBuilder
    private func gameContent(tick: Date) -> some View {
        GameTickDriver(date: tick, engine: engine)

        ZStack {
            roadBackground(scrollPhase: engine.roadScroll)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                gameHUD

                GeometryReader { fieldProxy in
                    gameField(size: fieldProxy.size)
                        .contentShape(Rectangle())
                        .gesture(swipeGesture)
                        .onTapGesture { engine.startIfNeeded() }
                }
            }
            .safeAreaPadding(.horizontal, 12)
            .safeAreaPadding(.top, 8)
            .safeAreaPadding(.bottom, 16)
            .screenShake(engine.screenShake)

            if engine.flashOpacity > 0 {
                (engine.flashIsRed ? Color.red : Color.orange)
                    .opacity(Double(engine.flashOpacity))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            overlayLayer

        }
        .background(Color.black)
    }

    private var gameHUD: some View {
        HStack(alignment: .center, spacing: 10) {
            GameDistanceProgressBar(
                distance: engine.distance,
                targetDistance: engine.targetDistance,
                level: level
            )

            CoinsPanelView(
                amount: progress.coins + engine.sessionCoins,
                height: 44
            )
            .frame(width: 118)

            ImageButton(imageName: "SettingsButton", action: handlePauseOrExit)
                .frame(width: 48, height: 48)
        }
        .padding(.bottom, 8)
    }

    private func roadBackground(scrollPhase: CGFloat) -> some View {
        GeometryReader { proxy in
            let tileHeight = proxy.size.height
            let scroll = scrollPhase.truncatingRemainder(dividingBy: 1) * tileHeight

            ZStack {
                Color(red: 0.08, green: 0.14, blue: 0.12)

                VStack(spacing: 0) {
                    roadTile(width: proxy.size.width, height: tileHeight)
                    roadTile(width: proxy.size.width, height: tileHeight)
                    roadTile(width: proxy.size.width, height: tileHeight)
                }
                .offset(y: scroll - tileHeight)
            }
        }
    }

    private func roadTile(width: CGFloat, height: CGFloat) -> some View {
        Image(GameAsset.roadBackground)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }

    private func gameField(size: CGSize) -> some View {
        let roadWidth = max(size.width * 0.62, 180)
        let playerSize = roadWidth * 0.34
        let entitySize = roadWidth * 0.26
        let playerX = laneX(for: engine.playerLane, fieldWidth: size.width, roadWidth: roadWidth)
        let playerY = size.height * 0.82
        let runSway = sin(engine.elapsedTime * 10) * 5

        return ZStack {
            ForEach(engine.entities) { entity in
                let x = laneX(for: entity.lane, fieldWidth: size.width, roadWidth: roadWidth)
                let y = size.height * entity.normalizedY
                let bob = entityBobOffset(for: entity)

                GameEntityShadow(width: entitySize)
                    .position(x: x, y: y + entitySize * 0.38)

                Image(entity.kind.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: entitySize, height: entitySize)
                    .scaleEffect(entityBobScale(for: entity))
                    .position(x: x, y: y + bob)
            }

            ForEach(engine.floatingLabels) { label in
                GameFloatingLabelView(
                    text: label.text,
                    progress: CGFloat(label.age / 0.9),
                    isCoin: label.isCoin
                )
                .position(
                    x: size.width * label.normalizedX,
                    y: size.height * label.normalizedY
                )
            }

            GameEntityShadow(width: playerSize)
                .position(x: playerX + runSway, y: playerY + playerSize * 0.38)

            if engine.pepperSparkPhase > 0 {
                GamePepperSparksView(phase: engine.pepperSparkPhase)
                    .position(x: playerX + runSway, y: playerY)
            }

            Image(engine.playerImageName)
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(180))
                .scaleEffect(x: engine.playerSquashX, y: engine.playerSquashY)
                .frame(width: playerSize, height: playerSize)
                .opacity(engine.playerHitActive ? 0.65 : 1)
                .overlay {
                    if engine.playerHitActive {
                        Color.red.opacity(0.35)
                            .blendMode(.multiply)
                            .frame(width: playerSize * 0.8, height: playerSize * 0.8)
                    }
                }
                .position(x: playerX + runSway, y: playerY)
                .animation(.easeOut(duration: 0.08), value: engine.playerLane)

            if let message = engine.statusMessage {
                GameToastBanner(message: message)
                    .transition(.scale.combined(with: .opacity))
                    .position(x: size.width / 2, y: size.height * 0.38)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func entityBobOffset(for entity: RunnerEntity) -> CGFloat {
        guard entity.kind == .egg || entity.kind == .pepper else { return 0 }
        let seed = CGFloat(entity.spawnTime * 7).truncatingRemainder(dividingBy: .pi * 2)
        return sin(engine.elapsedTime * 9 + seed) * 4
    }

    private func entityBobScale(for entity: RunnerEntity) -> CGFloat {
        guard entity.kind == .egg || entity.kind == .pepper else { return 1 }
        let seed = CGFloat(entity.spawnTime * 5).truncatingRemainder(dividingBy: .pi * 2)
        return 1 + sin(engine.elapsedTime * 11 + seed) * 0.06
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical), abs(horizontal) > 16 else { return }

                engine.startIfNeeded()
                if horizontal < 0 {
                    engine.moveLeft()
                } else {
                    engine.moveRight()
                }
            }
    }

    private func laneX(for lane: RunnerLane, fieldWidth: CGFloat, roadWidth: CGFloat) -> CGFloat {
        let center = fieldWidth / 2
        let offset = max(fieldWidth * 0.26, roadWidth * 0.34)
        switch lane {
        case .left: return center - offset
        case .right: return center + offset
        }
    }

    @ViewBuilder
    private var overlayLayer: some View {
        switch engine.phase {
        case .ready:
            ZStack {
                GamePopupBackdrop()
                GameStartPopup(onStart: { engine.startIfNeeded() })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { engine.startIfNeeded() }
            .gesture(swipeGesture)

        case .paused, .gameOver, .levelComplete:
            ZStack {
                GamePopupBackdrop()

                switch engine.phase {
                case .paused:
                    GamePausePopup(
                        onResume: { engine.resume() },
                        onExit: onExit
                    )
                case .gameOver:
                    GameEndPopup(
                        kind: .gameOver,
                        sessionCoins: engine.sessionCoins,
                        distance: engine.distance,
                        secondaryTitle: "EXIT",
                        onPrimary: {
                            didApplyRewards = false
                            engine.resetRun()
                        },
                        onSecondary: onExit
                    )
                case .levelComplete:
                    GameEndPopup(
                        kind: .levelComplete,
                        sessionCoins: engine.sessionCoins,
                        distance: engine.distance,
                        onPrimary: {
                            didApplyRewards = false
                            engine.resetRun()
                        },
                        onSecondary: onExit
                    )
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .safeAreaPadding(.horizontal, 20)
            .safeAreaPadding(.vertical, 24)

        case .playing:
            EmptyView()
        }
    }

    private func handlePauseOrExit() {
        switch engine.phase {
        case .playing:
            engine.pause()
        default:
            onExit()
        }
    }

    private func applyRewardsIfNeeded(for phase: RunnerPhase) {
        guard !didApplyRewards else { return }
        guard phase == .gameOver || phase == .levelComplete else { return }

        didApplyRewards = true
        progress.addCoins(engine.sessionCoins)
        progress.recordRoadCrossed(flawless: phase == .levelComplete)

        if phase == .levelComplete, engine.level == progress.levelsCompleted + 1 {
            progress.recordLevelCompleted()
        }
    }
}

private struct GameTickDriver: View {
    let date: Date
    var engine: RunnerGameEngine

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onChange(of: date) { _, newDate in
                tick(at: newDate)
            }
            .onChange(of: engine.phase) { _, phase in
                guard phase == .playing else { return }
                tick(at: date)
            }
    }

    private func tick(at date: Date) {
        guard engine.phase == .playing else { return }
        engine.update(at: date)
    }
}

#Preview {
    GameView(level: 1, progress: GameProgress())
}
