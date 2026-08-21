#if DEBUG
import SwiftUI

/// Отладочный маршрут: запуск сразу в нужный серый экран, минуя сеть и конфиг.
/// Нужен для съёмки шести экранов — по три в каждой ориентации.
///
///     -ShellPreviewRoute loadingLandscape
///
/// Маршрут `web` открывает витрину на заданном адресе. Он нужен приёмке: сервер
/// конфига выдаёт боевую ссылку либо отказывает, и без него `WKWebView` нечем
/// прогнать по тестовому ресурсу.
///
///     -ShellPreviewRoute web -ShellPreviewURL https://web.team-s.club/
enum PreviewRoute: String {
    case loading
    case offline
    case consent
    case loadingLandscape
    case offlineLandscape
    case consentLandscape
    case web

    var forcesLandscapeCanvas: Bool {
        switch self {
        case .loadingLandscape, .offlineLandscape, .consentLandscape:
            true
        case .loading, .offline, .consent, .web:
            false
        }
    }

    static var requested: PreviewRoute? {
        guard let value = argument(named: "-ShellPreviewRoute") else { return nil }
        return PreviewRoute(rawValue: value)
    }

    /// Адрес витрины для маршрута `web`.
    static var requestedWebURL: URL? {
        guard let value = argument(named: "-ShellPreviewURL") else { return nil }
        return URL(string: value)
    }

    private static func argument(named name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

enum PreviewCatalog {
    @ViewBuilder
    static func surface(for route: PreviewRoute) -> some View {
        if route.forcesLandscapeCanvas {
            ForcedLandscapeCanvas {
                content(for: route)
            }
        } else {
            content(for: route)
        }
    }

    @ViewBuilder
    private static func content(for route: PreviewRoute) -> some View {
        switch route {
        case .loading, .loadingLandscape:
            LoadingSurface()
        case .offline, .offlineLandscape:
            OfflineSurface(onRetry: {})
        case .consent, .consentLandscape:
            ConsentSurface(
                privacyPolicyURL: AppShellFacade.shared.privacyPolicyURL,
                onAccept: {},
                onSkip: {}
            )
        case .web:
            // Ветка повторяет боевую целиком: приёмка смотрит на ту же
            // поверхность, что увидит пользователь. Значка Privacy здесь нет
            // ровно потому, что его нет и в боевой витрине.
            WebSurface(
                url: PreviewRoute.requestedWebURL ?? URL(string: "https://web.team-s.club/")!,
                externalSchemes: AppShellFacade.shared.externalSchemes
            )
        }
    }
}

/// Портретное устройство поворачивать не нужно: холст разворачивается сам.
private struct ForcedLandscapeCanvas<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.height, height: proxy.size.width)
                .rotationEffect(.degrees(90))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

#Preview("Loading · Portrait") {
    LoadingSurface()
}

#Preview("Loading · Landscape", traits: .landscapeLeft) {
    LoadingSurface()
}

#Preview("Offline · Portrait") {
    OfflineSurface(onRetry: {})
}

#Preview("Offline · Landscape", traits: .landscapeLeft) {
    OfflineSurface(onRetry: {})
}

#Preview("Consent · Portrait") {
    ConsentSurface(privacyPolicyURL: nil, onAccept: {}, onSkip: {})
}

#Preview("Consent · Landscape", traits: .landscapeLeft) {
    ConsentSurface(privacyPolicyURL: nil, onAccept: {}, onSkip: {})
}
#endif
