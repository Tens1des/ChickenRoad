//
//  GameJuiceViews.swift
//  ChikenRoad
//

import SwiftUI

struct GameDistanceProgressBar: View {
    let distance: Int
    let targetDistance: Int
    let level: Int

    private var progress: CGFloat {
        guard targetDistance > 0 else { return 0 }
        return min(CGFloat(distance) / CGFloat(targetDistance), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LVL \(level)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 0)

                Text("\(distance)m / \(targetDistance)m")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.45))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.34, green: 0.78, blue: 0.22),
                                    Color(red: 0.98, green: 0.78, blue: 0.12)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, proxy.size.width * progress))
                        .animation(.easeOut(duration: 0.2), value: progress)

                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.5)
                }
            }
            .frame(height: 14)
        }
    }
}

struct GameEntityShadow: View {
    let width: CGFloat

    var body: some View {
        Ellipse()
            .fill(Color.black.opacity(0.28))
            .frame(width: width * 0.72, height: width * 0.22)
            .blur(radius: 1.5)
    }
}

struct GameFloatingLabelView: View {
    let text: String
    let progress: CGFloat
    let isCoin: Bool

    var body: some View {
        Text(text)
            .font(.system(size: isCoin ? 26 : 20, weight: .black, design: .rounded))
            .foregroundStyle(
                isCoin
                    ? LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.96, blue: 0.55),
                            Color(red: 1, green: 0.72, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(colors: [.white, .white.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: AppPalette.titleShadow, radius: 0, x: 0, y: 2)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            .scaleEffect(1 + (1 - progress) * 0.35)
            .opacity(Double(1 - progress))
    }
}

struct GamePepperSparksView: View {
    let phase: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * .pi * 2
                Circle()
                    .fill(
                        index.isMultiple(of: 2)
                            ? Color.red.opacity(0.85)
                            : Color.orange.opacity(0.9)
                    )
                    .frame(width: 7, height: 7)
                    .offset(
                        x: cos(angle) * 36 * phase,
                        y: sin(angle) * 36 * phase
                    )
                    .opacity(Double(1 - phase))
            }
        }
    }
}

struct ScreenShakeModifier: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(
                x: amount * sin(amount * 28),
                y: amount * cos(amount * 22)
            )
    }
}

extension View {
    func screenShake(_ amount: CGFloat) -> some View {
        modifier(ScreenShakeModifier(amount: amount))
    }
}
