//
//  CoinsPanelView.swift
//  ChikenRoad
//

import SwiftUI

struct CoinsPanelView: View {
    let amount: Int
    let height: CGFloat

    private var cornerRadius: CGFloat { height * 0.3 }

    var body: some View {
        HStack(spacing: 4) {
            Image("IconMoney")
                .resizable()
                .scaledToFit()
                .frame(width: height * 0.82, height: height * 0.82)
                .offset(x: -2)

            Text(amount.formattedCurrency)
                .font(.system(size: height * 0.44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppPalette.coinsTextShadow, radius: 0, x: 0, y: 2)
                .shadow(color: AppPalette.coinsTextShadow, radius: 0, x: 1, y: 1)
                .shadow(color: AppPalette.coinsTextShadow, radius: 0, x: -1, y: 1)
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
                            colors: [AppPalette.coinsPanelTop, AppPalette.coinsPanelBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppPalette.coinsBorderLight,
                                AppPalette.coinsBorderMid,
                                AppPalette.coinsBorderDark
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
