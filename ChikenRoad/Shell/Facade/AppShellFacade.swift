import Combine
import Foundation
import UIKit

/// Единственная публичная поверхность серого слоя.
///
/// Сеть узлов и контейнер зависимостей спрятаны здесь целиком: ни сцена, ни
/// системный мост, ни экраны не дотягиваются до них напрямую.
@MainActor
final class AppShellFacade: ObservableObject {
    static let shared = AppShellFacade()

    private let container: ShellContainer
    private var router: RouteCoordinator!
    private var exchange: ExchangeCoordinator!
    private var push: PushCoordinator!
    private var consent: ConsentCoordinator!
    private var routerBinding: AnyCancellable?
    private var signalsObserved = false

    init(container: ShellContainer = .shared) {
        self.container = container
        router = RouteCoordinator(context: self)
        exchange = ExchangeCoordinator(context: self)
        push = PushCoordinator(context: self)
        consent = ConsentCoordinator(context: self)
        // Состояние экрана живёт в узле маршрута; фасад только пересылает его
        // изменения наружу, не заводя вторую копию.
        routerBinding = router.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Экран

    var destination: ShellDestination { router.destination }

    /// Ориентации приложения на текущем экране. Спрашивает системный мост.
    var supportedOrientations: UIInterfaceOrientationMask {
#if DEBUG
        // Отладочный маршрут рисует экран мимо узла маршрута, и тот остаётся на
        // `.loading`. Без этой ветки витрина под маршрутом залипала бы в портрете
        // на установке, залоченной в native, — и поле поворота на приёмке
        // краснело бы на ровном месте.
        if PreviewRoute.requested != nil {
            return ShellOrientationPolicy.surfaceOrientations
        }
#endif
        return ShellOrientationPolicy.mask(
            for: router.destination,
            isNativeLocked: container.vault.installMode == .native
        )
    }

    var privacyPolicyURL: URL? { container.settings?.privacyPolicyURL }

    var externalSchemes: Set<String> { container.settings?.externalSchemes ?? [] }

    func start() {
        router.start()
    }

    func retry() {
        router.retry()
    }

    func acceptConsent() {
        consent.accept()
    }

    func skipConsent() {
        consent.skip()
    }

    // MARK: - Системные события

    func bootstrap(
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        container.bootstrap(application: application, launchOptions: launchOptions)
    }

    func setAPNSToken(_ token: Data) {
        container.messaging.setAPNSToken(token)
    }

    func receiveRemoteMessage(_ userInfo: [AnyHashable: Any]) {
        container.messaging.receiveRemoteMessage(userInfo)
    }

    @discardableResult
    func acceptPushPayload(_ userInfo: [AnyHashable: Any]) -> Bool {
        container.inbox.accept(userInfo: userInfo)
    }

    @discardableResult
    func handleOpen(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        container.signature.handleOpen(url, options: options)
    }

    @discardableResult
    func handleOpenFromScene(_ url: URL) -> Bool {
        container.signature.handleOpenFromScene(url)
    }

    @discardableResult
    func continueUserActivity(_ userActivity: NSUserActivity) -> Bool {
        container.signature.continue(userActivity)
    }
}

// MARK: - Контекст сети

extension AppShellFacade: MeshContext {
    var vault: ShellVault { container.vault }
    var settings: ShellSettings? { container.settings }
    var settingsFailure: Error? { container.settingsFailure }
    var startupFailure: Error? { container.startupFailure }

    var reachability: ReachabilityProbe { container.reachability }
    var messaging: MessagingBridge { container.messaging }
    var signature: InstallSignature { container.signature }
    var inbox: PushInbox { container.inbox }
    var consentGate: ConsentGate { container.consentGate }
    var envelope: ExchangeEnvelope { container.envelope }
    var linkExchange: LinkExchange { container.linkExchange }

    func observeSignals() {
        guard !signalsObserved else { return }
        signalsObserved = true
        push.observe()
        exchange.observe()
    }

    func show(_ destination: ShellDestination) {
        router.show(destination)
    }

    func showWeb(_ url: URL) {
        router.showWeb(url)
    }

    func armLoadingDeadline() {
        router.armLoadingDeadline()
    }

    func keepsVisibleWebDuringRefresh(fallback: LinkGrant?) -> Bool {
        router.keepsVisibleWebDuringRefresh(fallback: fallback)
    }

    var oneShotPushLink: URL? { push.oneShotLink }

    func adoptOneShotPushLink(_ url: URL) {
        push.adopt(url)
    }

    func scheduleExchange(forceRefresh: Bool) {
        exchange.schedule(forceRefresh: forceRefresh)
    }

    func presentPersistentWeb(_ url: URL) async {
        await consent.presentPersistentWeb(url)
    }
}
