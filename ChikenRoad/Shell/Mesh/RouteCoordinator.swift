import Combine
import UIKit
import Foundation

/// Узел экрана: что показано, в каком порядке стартует слой и сколько ждёт
/// загрузка.
@MainActor
final class RouteCoordinator: ObservableObject {
    @Published private(set) var destination: ShellDestination = .loading

    private weak var context: MeshContext?
    private var started = false
    /// Потолок ТЗ на видимую загрузку — десять секунд.
    private static let visibleLoadingBudgetNanoseconds: UInt64 = 10_000_000_000
    /// Шаг отсчёта. Мелкий нарочно: часы стоят, пока приложение неактивно, и
    /// возобновляются сразу после закрытия системного диалога.
    private static let deadlineTickNanoseconds: UInt64 = 250_000_000

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

#if DEBUG
        armAcceptanceRetryWatcher()
#endif
    }

#if DEBUG
    /// Приёмка без Accessibility: маркер в Caches контейнера приложения.
    private func armAcceptanceRetryWatcher() {
        Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let self else { return }
                let marker = AcceptanceMarkers.retry
                guard FileManager.default.fileExists(atPath: marker.path) else { continue }
                try? FileManager.default.removeItem(at: marker)
                self.retry()
            }
        }
    }
#endif

    func retry() {
        // Связность перечитывается прямо здесь. Иначе кнопка «Retry» на экране
        // «нет интернета» упирается в закэшированное `offline`: `StartResolver`
        // сразу возвращает тот же экран, заявка не уходит, и для пользователя
        // кнопка просто не работает — хотя интернет он уже включил.
        context?.reachability.refreshNow()
        resetLoadingDeadline()
        show(.loading)
        armLoadingDeadline()
        context?.scheduleExchange(forceRefresh: false)
    }

    func show(_ destination: ShellDestination) {
        if destination == .loading {
            self.destination = destination
            // Идемпотентно: если часы уже идут, второй вызов их не сдвигает.
            // Нужно потому, что в загрузку можно вернуться и мимо `start()` —
            // например из ветки ожидания связности, — и тогда экран оставался
            // бы без потолка вовсе.
            armLoadingDeadline()
            return
        }

        // Ушли с загрузки — часы останавливаются. Иначе взведённый дедлайн
        // сработает поверх уже показанной витрины.
        loadingDeadlineTask?.cancel()
        loadingDeadlineTask = nil
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
        // Десять секунд отсчитываются от момента, когда загрузка ПОЯВИЛАСЬ на
        // экране, и повторный вызов их не сдвигает. Раньше каждая попытка обмена
        // перезаряжала таймер, а колбэк связности порождал попытки быстрее, чем
        // тот успевал сработать, — экран загрузки жил неограниченно долго.
        guard loadingDeadlineTask == nil else {
            return
        }
        loadingDeadlineTask = Task { @MainActor [weak self] in
            // Часы идут только пока приложение активно. Системный диалог — ATT,
            // разрешение на уведомления — уводит его в `.inactive`, и без этой
            // паузы потолок досчитывался бы прямо под диалогом: пользователь
            // закрывал бы его уже поверх экрана «нет интернета».
            var remaining = Self.visibleLoadingBudgetNanoseconds
            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.deadlineTickNanoseconds)
                guard UIApplication.shared.applicationState == .active else { continue }
                remaining -= min(remaining, Self.deadlineTickNanoseconds)
            }
            guard !Task.isCancelled,
                  let self,
                  let context = self.context,
                  self.destination == .loading,
                  context.vault.installMode != .native else {
                return
            }

            // Колбэк связности или ответ сервиса могут прийти и позже. Дедлайн
            // гарантирует только одно: анимированная заглушка не висит на экране
            // дольше десяти секунд. Режим он не лочит.
            self.show(.offline)
        }
    }

    /// Явный сброс потолка: пользователь начал заново.
    func resetLoadingDeadline() {
        loadingDeadlineTask?.cancel()
        loadingDeadlineTask = nil
    }
}
