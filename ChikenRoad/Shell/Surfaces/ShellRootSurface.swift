import SwiftUI

/// Корневой экран серого слоя: одна ветка на каждое состояние.
///
/// Игра приходит сюда содержимым native-режима и о существовании слоя не знает.
struct ShellRootSurface<GameContent: View>: View {
    @ObservedObject var shell: AppShellFacade
    @ViewBuilder let game: () -> GameContent

    var body: some View {
        Group {
            switch shell.destination {
            case .loading:
                LoadingSurface()

            case .offline:
                OfflineSurface(onRetry: shell.retry)

            case .recoverableFailure(let message):
                RecoverableFailureSurface(message: message, onRetry: shell.retry)

            case .setupRequired(let message):
                SetupRequiredSurface(message: message)

            case .consent:
                ConsentSurface(
                    privacyPolicyURL: shell.privacyPolicyURL,
                    onAccept: shell.acceptConsent,
                    onSkip: shell.skipConsent
                )

            case .web(let url):
                // Одна ветка на весь web-режим и никакого `.id(url)`: смена
                // адреса идёт обновлением того же самого webview, иначе теряются
                // cookies, сессия и скролл.
                // Значка Privacy здесь нет намеренно: заказчик просил убрать
                // его с витрины. В native-ветке он остаётся — там доступ к
                // политике требует ревью App Store.
                WebSurface(url: url, externalSchemes: shell.externalSchemes)

            case .game:
                // Privacy Policy обязана быть доступна и в native-режиме. Вход
                // добавляет слой поверх игры, а не сама игра: связь остаётся
                // односторонней.
                GameSurface(privacyPolicyURL: shell.privacyPolicyURL, game: game)
            }
        }
        .task {
            shell.start()
        }
        .onChange(of: shell.destination) {
            // Игра портретная, витрина и шесть экранов — нет. Смена ветки
            // меняет маску приложения, и систему надо попросить её перечитать.
            ShellOrientationPolicy.refresh()
        }
    }
}

/// Игра плюс вход в Privacy Policy.
///
/// Вход висит в нижней системной полосе, **под** интерактивным полем игры.
/// Иначе он съедает управление: касание достаётся верхнему слою целиком, до
/// игры не доходит вовсе, и свайп смены полосы, начатый со значка, пропадает.
/// Замерено на живом экране — жест из нейтральной точки полосу меняет, со
/// значка не менял.
///
/// Граница поля известна из белой части: `GameView` кладёт поле в стек с
/// `safeAreaPadding(.bottom, 16)`, то есть оно кончается на 16 pt выше safe
/// area. Значок опускается ровно в эту полосу — своей вставкой устройства, а не
/// подобранным числом: на модели без нижней вставки сдвигать некуда.
private struct GameSurface<GameContent: View>: View {
    let privacyPolicyURL: URL?
    @ViewBuilder let game: () -> GameContent

    var body: some View {
        game()
            .overlay(alignment: .bottomLeading) {
                if let privacyPolicyURL {
                    PrivacyBadge(destination: privacyPolicyURL, compact: true)
                        .padding(.leading, 12)
                        .padding(.bottom, 8)
                        // Safe area игнорирует **только** значок: у игры своя
                        // раскладка от вставок устройства, и трогать её нельзя.
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
    }
}

private struct PrivacyBadge: View {
    let destination: URL
    var compact = false

    var body: some View {
        Link(destination: destination) {
            Label("Privacy", systemImage: "hand.raised.fill")
                .labelStyle(.titleAndIcon)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .padding(.horizontal, compact ? 10 : 12)
                .frame(minHeight: compact ? 32 : 40)
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(.primary.opacity(0.10), lineWidth: 1)
                }
        }
        .foregroundStyle(.primary)
        .opacity(compact ? 0.75 : 1)
        .accessibilityHint("Opens the privacy policy")
    }
}

private struct RecoverableFailureSurface: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        CrossingScaffold(contentMaxWidth: 480) { layout in
            VStack(spacing: 20) {
                CrossingBadge(
                    systemName: "arrow.trianglehead.2.clockwise.rotate.90",
                    accessibilityLabel: "Unable to continue",
                    compact: layout.usesSideBySideContent
                )

                VStack(spacing: 8) {
                    CrossingHeadline(text: "UNABLE TO CONTINUE")

                    CrossingBodyText(text: message)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)

                Button("Retry", action: onRetry)
                    .buttonStyle(CrossingPrimaryButtonStyle())
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Экран невалидной конфигурации. Он обязан быть честным и заметным: молчаливый
/// запрос с плейсхолдером внутри хуже видимой надписи.
private struct SetupRequiredSurface: View {
    let message: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("Configuration Required")
                        .font(.title2.bold())
                    Text(message)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Update Shell/Resources/ShellConfig.plist and add the matching GoogleService-Info.plist before release.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
