import Combine
import Foundation

/// Узел обмена с сервером: склейка заявок, лок режима, fallback и отметка о
/// доставленном токене.
///
/// Цикл склейки живёт целиком здесь и наружу не растаскивается — иначе смена
/// токена во время запроса даёт дубли.
@MainActor
final class ExchangeCoordinator {
    private weak var context: MeshContext?
    private var subscriptions = Set<AnyCancellable>()
    private var exchangeTask: Task<Void, Never>?
    private var pendingExchange = false
    private var pendingForceRefresh = false

    init(context: MeshContext) {
        self.context = context
    }

    /// Смена токена FCM — повод для немедленной новой заявки.
    func observe() {
        NotificationCenter.default.publisher(for: MessagingBridge.tokenDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.schedule(forceRefresh: true)
            }
            .store(in: &subscriptions)
    }

    func schedule(forceRefresh: Bool) {
        guard let context, context.settings != nil else { return }
        pendingExchange = true
        pendingForceRefresh = pendingForceRefresh || forceRefresh
        guard exchangeTask == nil else { return }

        exchangeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while pendingExchange, !Task.isCancelled {
                pendingExchange = false
                let force = pendingForceRefresh
                pendingForceRefresh = false
                await evaluate(forceRefresh: force)
            }
            exchangeTask = nil
        }
    }

    private func evaluate(forceRefresh: Bool) async {
        guard let context, let settings = context.settings else { return }

        if let pushLink = context.oneShotPushLink {
            context.showWeb(pushLink)
        }

        let currentToken = context.messaging.currentToken
        let hasUndeliveredToken = currentToken != nil
            && currentToken != context.vault.deliveredPushToken

        let action = StartResolver.resolve(
            mode: context.vault.installMode,
            grant: context.vault.storedGrant,
            reachability: context.reachability.state,
            forceRefresh: forceRefresh || hasUndeliveredToken
        )

        switch action {
        case .awaitReachability:
            if context.oneShotPushLink == nil { context.show(.loading) }

        case .handOverToGame:
            guard context.oneShotPushLink == nil else { return }
            context.show(.game)

        case .reportOffline:
            guard context.oneShotPushLink == nil else { return }
            context.show(.offline)

        case .openGrant(let grant):
            guard let url = grant.destination else {
                await performExchange(settings: settings, fallback: nil)
                return
            }
            await context.presentPersistentWeb(url)

        case .exchange(_, let fallback):
            await performExchange(settings: settings, fallback: fallback)
        }
    }

    private func performExchange(settings: ShellSettings, fallback: LinkGrant?) async {
        guard let context else { return }

        // Native — установочный лок: ни поздний refresh токена, ни событие
        // жизненного цикла не имеют права его обойти.
        guard context.vault.permitsExchange else {
            if context.oneShotPushLink == nil { context.show(.game) }
            return
        }

        if context.oneShotPushLink == nil,
           !context.keepsVisibleWebDuringRefresh(fallback: fallback) {
            context.show(.loading)
            context.armLoadingDeadline()
        }

        // Атрибуция и токен ждутся параллельно, а не по очереди.
        async let attribution = context.signature.snapshot(waitingUpTo: 3)
        async let token = context.messaging.tokenSnapshot(waitUpTo: 2)
        let (attributionValues, pushToken) = await (attribution, token)

        let body: [String: Any]
        do {
            body = try context.envelope.seal(
                attribution: attributionValues,
                appsFlyerUID: context.signature.installID,
                bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                storeID: settings.storeID,
                locale: .current,
                pushToken: pushToken,
                firebaseProjectID: context.messaging.projectID
            )
        } catch {
            showFailure(
                message: "The installation data is not ready yet. Please try again.",
                fallback: fallback
            )
            return
        }

        do {
            let receipt = try await context.linkExchange.ask(
                endpoint: settings.exchangeEndpoint,
                envelope: body
            )
            markTokenDelivered(pushToken, if: receipt.answeredOverHTTP)

            switch receipt.verdict {
            case .granted(let grant):
                context.vault.sealWeb(grant)
                guard let url = grant.destination else {
                    showFailure(message: "The server returned an invalid link.", fallback: fallback)
                    return
                }
                await context.presentPersistentWeb(url)

            case .declined:
                // Отказ на первом решении — native навсегда. Отказ на уже
                // залоченном web режим не трогает.
                if context.vault.installMode == .undecided {
                    context.vault.sealNative()
                    if context.oneShotPushLink == nil { context.show(.game) }
                } else {
                    showFailure(message: "The latest link is temporarily unavailable.", fallback: fallback)
                }
            }
        } catch let exchangeError as LinkExchangeError {
            markTokenDelivered(pushToken, if: exchangeError.answeredOverHTTP)
            let message: String
            switch exchangeError {
            case .transport:
                message = "No internet connection. Check your connection and try again."
            default:
                message = "The configuration service returned an invalid response. Please try again."
            }
            showFailure(message: message, fallback: fallback)
        } catch {
            showFailure(message: "The service is temporarily unavailable. Please try again.", fallback: fallback)
        }

        // Токен успел смениться прямо во время запроса — планируем ещё одну
        // заявку, ровно одну.
        let newestToken = context.messaging.currentToken
        if context.vault.installMode == .web,
           let newestToken,
           newestToken != pushToken,
           newestToken != context.vault.deliveredPushToken {
            schedule(forceRefresh: true)
        }
    }

    private func showFailure(message: String, fallback: LinkGrant?) {
        guard let context, context.oneShotPushLink == nil else { return }

        if context.vault.installMode == .web,
           let fallback,
           let url = fallback.destination {
            Task { @MainActor [weak context] in
                await context?.presentPersistentWeb(url)
            }
            return
        }

        if context.reachability.state == .offline || message.hasPrefix("No internet") {
            context.show(.offline)
        } else {
            context.show(.recoverableFailure(message))
        }
    }

    /// Доставка засчитывается только по фактическому HTTP-ответу — любому,
    /// включая не-200 и битый 200. Обрыв транспорта доставкой не считается.
    private func markTokenDelivered(_ token: String?, if answeredOverHTTP: Bool) {
        guard answeredOverHTTP, let token, !token.isEmpty else { return }
        context?.vault.deliveredPushToken = token
    }
}
