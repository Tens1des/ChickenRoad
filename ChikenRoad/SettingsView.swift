//
//  SettingsView.swift
//  ChikenRoad
//

import SwiftUI

struct SettingsView: View {
    var onBack: () -> Void = {}

    @AppStorage("isSoundEnabled") private var isSoundEnabled = true
    @AppStorage("isMusicEnabled") private var isMusicEnabled = true

    @State private var layoutSize: CGSize = .zero

    var body: some View {
        ZStack {
            Image("BgSettings")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)

                    SettingsImageButton(imageName: "SettingsButton", action: onBack)
                        .frame(
                            width: max(layoutSize.width * 0.17, 52),
                            height: max(layoutSize.width * 0.17, 52)
                        )
                }
                .padding(.top, layoutSize.height * 0.10)

                Spacer(minLength: 0)
            }
            .overlay(alignment: .center) {
                settingsPanel
                    .offset(y: layoutSize.height * 0.06)
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

    private var settingsPanel: some View {
        let contentWidth = max(layoutSize.width, 320)
        let rowSpacing = max(layoutSize.height * 0.012, 8)

        return VStack(spacing: rowSpacing) {
            SettingsToggleRow(
                labelImageName: "SoundLabel",
                isOn: $isSoundEnabled,
                layoutWidth: contentWidth
            )

            SettingsToggleRow(
                labelImageName: "MusicLabel",
                isOn: $isMusicEnabled,
                layoutWidth: contentWidth
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsToggleRow: View {
    let labelImageName: String
    @Binding var isOn: Bool
    let layoutWidth: CGFloat

    var body: some View {
        let labelWidth = layoutWidth * 0.50
        let toggleWidth = layoutWidth * 0.28
        let labelToggleSpacing = max(layoutWidth * 0.004, 2)

        VStack(spacing: labelToggleSpacing) {
            Image(labelImageName)
                .resizable()
                .scaledToFit()
                .frame(width: labelWidth)
                .fixedSize(horizontal: false, vertical: true)

            SettingsImageButton(
                imageName: isOn ? "OnState" : "OffState",
                action: { isOn.toggle() }
            )
            .frame(width: toggleWidth)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsImageButton: View {
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
    SettingsView()
}
