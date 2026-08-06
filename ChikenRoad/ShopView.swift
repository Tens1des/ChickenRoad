//
//  ShopView.swift
//  ChikenRoad
//

import SwiftUI

struct ShopView: View {
    var progress: GameProgress
    var onBack: () -> Void = {}

    @State private var layoutSize: CGSize = .zero

    private var horizontalPadding: CGFloat { max(layoutSize.width * 0.05, 16) }
    private var cardSpacing: CGFloat { max(layoutSize.width * 0.04, 12) }
    private var cardWidth: CGFloat {
        let available = max(layoutSize.width - horizontalPadding * 2 - cardSpacing, 280)
        return available / 2
    }

    var body: some View {
        ZStack {
            Image("BgShop")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                shopHeader
                    .padding(.top, layoutSize.height * 0.10)

                skinList
                    .padding(.top, layoutSize.height * 0.04)
            }
            .safeAreaPadding(.horizontal, horizontalPadding)
            .safeAreaPadding(.top, 10)
            .safeAreaPadding(.bottom, 24)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { _, newSize in
                layoutSize = newSize
            }
        }
    }

    private var shopHeader: some View {
        let topButtonSize = max(layoutSize.width * 0.13, 44)
        let backButtonSize = max(layoutSize.width * 0.17, 52)
        let coinsPanelWidth = topButtonSize * 2.35

        return HStack(alignment: .center, spacing: 12) {
            ShopCoinsPanelView(amount: progress.coins, height: topButtonSize)
                .frame(width: coinsPanelWidth)

            Spacer(minLength: 0)

            ShopImageButton(imageName: "SettingsButton", action: onBack)
                .frame(width: backButtonSize, height: backButtonSize)
        }
        .frame(maxWidth: .infinity)
    }

    private var skinList: some View {
        let columns = [
            GridItem(.flexible(), spacing: cardSpacing),
            GridItem(.flexible(), spacing: cardSpacing)
        ]

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: cardSpacing) {
                ForEach(ShopSkin.catalog) { skin in
                    ShopSkinCard(
                        skin: skin,
                        isOwned: progress.isOwned(skin),
                        isSelected: progress.isSelected(skin),
                        cardWidth: cardWidth,
                        onTap: { progress.handleSkinTap(skin) }
                    )
                }
            }
            .padding(.bottom, cardSpacing)
        }
    }
}

private struct ShopSkinCard: View {
    let skin: ShopSkin
    let isOwned: Bool
    let isSelected: Bool
    let cardWidth: CGFloat
    let onTap: () -> Void

    private var cardHeight: CGFloat { cardWidth * 1.3 }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                skinCardFrame

                Image(skin.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, cardWidth * 0.08)
                    .padding(.top, cardWidth * 0.1)
                    .padding(.bottom, cardWidth * 0.24)

                VStack {
                    HStack {
                        Spacer(minLength: 0)

                        if isSelected {
                            selectedBadge
                        }
                    }
                    .padding(.top, cardWidth * 0.05)
                    .padding(.trailing, cardWidth * 0.05)

                    Spacer(minLength: 0)

                    if !isSelected {
                        actionButton
                            .padding(.horizontal, cardWidth * 0.1)
                            .padding(.bottom, cardWidth * 0.07)
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .buttonStyle(.plain)
    }

    private var skinCardFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardWidth * 0.08, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.48, blue: 0.24),
                            Color(red: 0.52, green: 0.32, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cardWidth * 0.07, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.62, blue: 0.34),
                            Color(red: 0.68, green: 0.44, blue: 0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(cardWidth * 0.025)

            RoundedRectangle(cornerRadius: cardWidth * 0.06, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.86, blue: 0.45),
                            Color(red: 0.72, green: 0.48, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: cardWidth * 0.025
                )
                .padding(cardWidth * 0.012)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }

    private var selectedBadge: some View {
        Text("SELECTED")
            .font(.system(size: cardWidth * 0.075, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, cardWidth * 0.05)
            .padding(.vertical, cardWidth * 0.025)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.34, green: 0.78, blue: 0.22),
                                Color(red: 0.18, green: 0.58, blue: 0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    }
            }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isOwned {
            priceCapsule(title: "USE", showsCoin: false)
        } else if skin.price == 0 {
            priceCapsule(title: "FREE", showsCoin: false)
        } else {
            priceCapsule(title: formattedPrice(skin.price), showsCoin: true)
        }
    }

    private func priceCapsule(title: String, showsCoin: Bool) -> some View {
        HStack(spacing: cardWidth * 0.03) {
            if showsCoin {
                Image("IconMoney")
                    .resizable()
                    .scaledToFit()
                    .frame(width: cardWidth * 0.12, height: cardWidth * 0.12)
            }

            Text(title)
                .font(.system(size: cardWidth * 0.11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0.12, green: 0.32, blue: 0.08), radius: 0, x: 0, y: 1)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, cardWidth * 0.045)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.34, green: 0.78, blue: 0.22),
                            Color(red: 0.18, green: 0.58, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 2)
                }
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    private func formattedPrice(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

private struct ShopCoinsPanelView: View {
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
                                Color(red: 0.72, green: 0.48, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: height * 0.07
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
    }
}

private struct ShopImageButton: View {
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
    ShopView(progress: GameProgress())
}
