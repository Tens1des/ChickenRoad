import Combine
import Foundation

/// Узел экрана: что показано, в каком порядке стартует слой и сколько ждёт
/// загрузка.
@MainActor
final class RouteCoordinator: ObservableObject {
    @Published private(set) var destination: ShellDestination = .loading

    private weak var context: MeshContext?
    private var started = false
    private var loadingDeadlineTask: Task<Void, Never>?

    init(context: MeshContext) {
        self.context = context
    }

    func start() {
        guard !started else { return }
        started = true
        guard let context else { return }

        // Подписки поднимаются до чтения режима. Маршрутизация пуша обязана
        // работать и на установке, навсегда залоченной в native: ссылка из
        // уведомления — одноразовое перекрытие экрана в памяти, она не снимает
        // лок и не запускает заявку к конфигу.
        context.observeSignals()

        // Выбор native постоянен для этой установки и не зависит ни от сети, ни
        // от SDK, ни даже от более поздней ошибки в конфигурации.
        if context.vault.installMode == .native {
            if let pushLink = context.inbox.consume() {
                context.adoptOneShotPushLink(pushLink)
            } else {
                show(.game)
            }
            return
        }

        if let failure = context.settingsFailure {
            show(.setupRequired(failure.localizedDescription))
            return
        }

        if let startupFailure = context.startupFailure {
            show(.setupRequired(startupFailure.localizedDescription))
            return
        }

        armLoadingDeadline()
        context.reachability.begin { [weak self] state in
            guard let self, let context = self.context else { return }
            if state == .offline,
               context.vault.installMode != .native,
               self.destination == .loading || self.destination == .offline {
                self.show(.offline)
            }
            if state == .online {
                context.scheduleExchange(forceRefresh: false)
            }
        }

        if let pushLink = context.inbox.consume() {
            context.adoptOneShotPushLink(pushLink)
        } else {
            context.scheduleExchange(forceRefresh: false)
        }
    }

    func retry() {
        show(.loading)
        armLoadingDeadline()
        context?.scheduleExchange(forceRefresh: false)
    }

    func show(_ destination: ShellDestination) {
        self.destination = destination
    }

    func showWeb(_ url: URL) {
        show(.web(url))
    }

    /// Обновление в фоне не должно смахивать уже открытую витрину на загрузку.
    func keepsVisibleWebDuringRefresh(fallback: LinkGrant?) -> Bool {
        guard fallback != nil else { return false }
        switch destination {
        case .web, .consent:
            return true
        default:
            return false
        }
    }

    /// Десять секунд — потолок ТЗ на видимую загрузку.
    func armLoadingDeadline() {
        loadingDeadlineTask?.cancel()
        loadingDeadlineTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled,
                  let self,
                  let context = self.context,
                  self.destination == .loading,
                  context.vault.installMode != .native else { return }

            // Колбэк связности или ответ сервиса могут прийти и позже. Дедлайн
            // гарантирует только одно: анимированная заглушка не висит на экране
            // дольше десяти секунд. Режим он не лочит.
            self.show(.offline)
        }
    }
}
