import Combine
import Foundation

/// Узел пуша: одноразовая ссылка из уведомления и ничего больше.
@MainActor
final class PushCoordinator {
    private weak var context: MeshContext?
    private var subscriptions = Set<AnyCancellable>()
    private(set) var oneShotLink: URL?

    init(context: MeshContext) {
        self.context = context
    }

    func observe() {
        NotificationCenter.default.publisher(for: PushInbox.didAcceptLink)
            .receive(on: RunLoop.main)
            .compactMap { $0.userInfo?["url"] as? URL }
            .sink { [weak self] url in
                self?.adopt(url)
            }
            .store(in: &subscriptions)
    }

    /// Живой слой получил событие, но во входящем ящике всё ещё лежит копия
    /// холодного старта. Она забирается здесь, иначе следующая сцена покажет уже
    /// показанный пуш второй раз.
    func adopt(_ url: URL) {
        guard let context else { return }
        _ = context.inbox.consume()
        oneShotLink = url
        context.showWeb(url)
    }
}
