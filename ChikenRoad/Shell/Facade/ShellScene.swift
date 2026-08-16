import SwiftUI

/// Обёртка сцены: единственное, что игра о слое «видит» — то, что её корневой
/// экран передан сюда замыканием.
///
///     WindowGroup {
///         ShellScene { ContentView() }
///     }
struct ShellScene<GameContent: View>: View {
    @StateObject private var shell = AppShellFacade.shared
    private let game: () -> GameContent

    init(@ViewBuilder game: @escaping () -> GameContent) {
        self.game = game
    }

    var body: some View {
#if DEBUG
        if let route = PreviewRoute.requested {
            PreviewCatalog.surface(for: route)
        } else {
            liveContent
        }
#else
        liveContent
#endif
    }

    private var liveContent: some View {
        ShellRootSurface(shell: shell, game: game)
            .onOpenURL { url in
                shell.handleOpenFromScene(url)
            }
    }
}
