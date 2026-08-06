//
//  MainMenuView.swift
//  ChikenRoad
//

import SwiftUI

struct MainMenuView: View {
    var coins: Int = 0
    var onPlay: () -> Void = {}
    var onShop: () -> Void = {}
    var onAchievements: () -> Void = {}
    var onSettings: () -> Void = {}

    @State private var layoutSize: CGSize = .zero

    var body: some View {
        ZStack {
            Image("BgMain")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopHeaderBar(coins: coins, onSettings: onSettings)
                    .padding(.top, layoutSize.height * 0.10)

                Spacer(minLength: 0)

                SideButtonsBar(
                    onShop: onShop,
                    onAchievements: onAchievements,
                    layoutWidth: layoutSize.width
                )
            }
            .overlay(alignment: .bottom) {
                MenuImageButton(imageName: "PlayButton", action: onPlay)
                    .frame(width: layoutSize.width * 0.50)
                    .padding(.bottom, layoutSize.height * 0.01)
            }
            .safeAreaPadding(.horizontal, 16)
            .safeAreaPadding(.top, 10)
            .safeAreaPadding(.bottom, 40)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { _, newSize in
                layoutSize = newSize
            }
        }
    }
}

private struct TopHeaderBar: View {
    let coins: Int
    let onSettings: () -> Void

    @State private var containerWidth: CGFloat = 0

    var body: some View {
        let topButtonSize = max(containerWidth * 0.13, 44)
        let settingsButtonSize = max(containerWidth * 0.17, 52)
        let coinsPanelWidth = topButtonSize * 2.35

        HStack(alignment: .center, spacing: 12) {
            CoinsPanelView(amount: coins, height: topButtonSize)
                .frame(width: coinsPanelWidth)

            Spacer(minLength: 0)

            MenuImageButton(imageName: "SettingsButton", action: onSettings)
                .frame(width: settingsButtonSize, height: settingsButtonSize)
        }
        .frame(maxWidth: .infinity, minHeight: settingsButtonSize)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { _, newWidth in
            containerWidth = newWidth
        }
    }
}

private struct SideButtonsBar: View {
    var onShop: () -> Void
    var onAchievements: () -> Void
    let layoutWidth: CGFloat

    var body: some View {
        let sideButtonSize = max(layoutWidth * 0.21, 0)
        let sideButtonsLift = max(layoutWidth * 0.08, 0)

        HStack(alignment: .bottom, spacing: 0) {
            MenuImageButton(imageName: "ShopButton", action: onShop)
                .frame(width: sideButtonSize, height: sideButtonSize)

            Spacer()

            MenuImageButton(imageName: "AchivButton", action: onAchievements)
                .frame(width: sideButtonSize, height: sideButtonSize)
        }
        .padding(.bottom, sideButtonsLift)
    }
}

private struct CoinsPanelView: View {
    let amount: Int
    let height: CGFloat

    private var cornerRadius: CGFloat { height * 0.3 }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image("IconMoney")
                .resizable()
                .scaledToFit()
                .frame(width: height * 0.82, height: height * 0.82)
                .offset(x: -2)

            Text(formattedAmount)
                .font(.system(size: height * 0.44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0.28, green: 0.12, blue: 0.04), radius: 0, x: 0, y: 2)
                .shadow(color: Color(red: 0.28, green: 0.12, blue: 0.04), radius: 0, x: 1, y: 1)
                .shadow(color: Color(red: 0.28, green: 0.12, blue: 0.04), radius: 0, x: -1, y: 1)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(height: height)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.18, blue: 0.1),
                                Color(red: 0.58, green: 0.1, blue: 0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.86, blue: 0.45),
                                Color(red: 0.72, green: 0.48, blue: 0.14),
                                Color(red: 0.45, green: 0.28, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: height * 0.07
                    )

                RoundedRectangle(cornerRadius: cornerRadius * 0.85, style: .continuous)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
                    .padding(height * 0.06)
            }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
    }
}

private struct MenuImageButton: View {
    let imageName: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .scaleEffect(isPressed ? 0.94 : 1)
                .animation(.easeOut(duration: 0.12), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    MainMenuView(coins: 1250)
}
