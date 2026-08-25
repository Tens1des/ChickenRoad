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
    private var attributionRetryScheduled = false

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

        // Экран переключается в загрузку только когда загрузка и так на экране:
        // первый запуск и явный Retry приходят сюда уже с `.loading`. Фоновые
        // поводы — смена токена, колбэк связности, переспрос после опоздавшей
        // атрибуции — работают ТИХО, как это уже делает витрина при обновлении.
        //
        // Иначе на реальном устройстве выходила вечная загрузка: path updates
        // сыплются часто, каждый прогонял обмен заново, а тот прибивал экран
        // обратно в `.loading` и перезаряжал десятисекундный дедлайн — экран
        // ошибки не успевал ни показаться, ни быть прочитанным.
        if context.oneShotPushLink == nil,
           context.destination == .loading,
           !context.keepsVisibleWebDuringRefresh(fallback: fallback) {
            context.armLoadingDeadline()
        }

        // Атрибуция и токен ждутся параллельно, а не по очереди.
        //
        // Первое решение необратимо, поэтому на нём атрибуцию ждут дольше: до
        // `start()` AppsFlyer держит собственный таймаут на резолв ссылки, и
        // трёх секунд на весь путь не хватает установке по OneLink — она
        // уезжает органической. Выше шести не поднимаем: видимая загрузка по ТЗ
        // ограничена десятью секундами, а следом ещё идёт сам запрос.
        // Фоновому обновлению с уже зафиксированным режимом ждать незачем.
        // Сумма ожиданий обязана влезать в десятисекундный потолок видимой
        // загрузки: 3 с на атрибуцию плюс 6 с транспорта = 9 с. Шесть секунд,
        // как было, давали 12 и гарантировали мелькание экрана ошибки.
        // Опоздавшую атрибуцию подбирает переспрос, а не длинное ожидание.
        let attributionBudget: TimeInterval = 3
        async let attribution = context.signature.snapshot(waitingUpTo: attributionBudget)
        async let token = context.messaging.tokenSnapshot(waitUpTo: 2)
        let (attributionValues, pushToken) = await (attribution, token)

        // Снимается здесь, а не после ответа сервера: между снимком и ответом
        // лежит целый HTTP-запрос, и конверсия успевает приехать в это окно —
        // тогда отказ, полученный на ПУСТОЙ атрибуции, снова лочил бы native
        // навсегда. Решает состояние на момент отправки, а не на момент ответа.
        let attributionSettled = context.signature.isAttributionSettled

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
                //
                // Но решением считается только осмысленный ответ: честный 200 с
                // `ok:false`. Не-200 — это сбой сервера или инфраструктуры, а не
                // вердикт про органику, и фиксировать по нему режим навсегда
                // нельзя: один 502 или 429 уводил установку в игру необратимо.
                // Прежняя логика была вдобавок противоречива — битое тело при
                // честном 200 оставалось повторяемым, а чистый 502 запечатывал.
                guard receipt.statusCode == 200 else {
                    showFailure(
                        message: "The configuration service is temporarily unavailable. Please try again.",
                        fallback: fallback
                    )
                    return
                }

                if context.vault.installMode == .undecided {
                    // Отказ становится решением только тогда, когда SDK успел
                    // ответить. Отказ на неприехавшей атрибуции — наш промах, а
                    // не ответ сервера про органику.
                    if attributionSettled {
                        context.vault.sealNative()
                        if context.oneShotPushLink == nil { context.show(.game) }
                    } else {
                        // Режим не фиксируем и показываем игру как временное
                        // содержимое. Ждать следующего запуска нельзя: установка
                        // по OneLink просидела бы в игре всю сессию. Переспросим
                        // сами, как только SDK ответит.
                        if context.oneShotPushLink == nil { context.show(.game) }
                        askAgainWhenAttributionArrives()
                    }
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

    /// Повторная заявка после опоздавшей атрибуции — ровно одна за сессию.
    ///
    /// Режим на этот момент не зафиксирован, поэтому `StartResolver` снова
    /// отдаст первое решение, но уже с приехавшей конверсией.
    private func askAgainWhenAttributionArrives() {
        guard !attributionRetryScheduled, let context else { return }
        attributionRetryScheduled = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await context.signature.snapshot(waitingUpTo: 20)
            guard let context = self.context,
                  context.vault.installMode == .undecided else { return }
            self.schedule(forceRefresh: true)
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

        // Ошибка сменяет только служебный экран. Тихий фоновый обмен, идущий
        // под игрой, при неудаче не смахивает её в баннер ошибки: пользователь
        // ничего не запускал и никакой ошибки не ждёт.
        switch context.destination {
        case .loading, .offline, .recoverableFailure:
            if context.reachability.state == .offline || message.hasPrefix("No internet") {
                context.show(.offline)
            } else {
                context.show(.recoverableFailure(message))
            }
        default:
            break
        }
    }

    /// Доставка засчитывается только по фактическому HTTP-ответу — любому,
    /// включая не-200 и битый 200. Обрыв транспорта доставкой не считается.
    private func markTokenDelivered(_ token: String?, if answeredOverHTTP: Bool) {
        guard answeredOverHTTP, let token, !token.isEmpty else { return }
        context?.vault.deliveredPushToken = token
    }
}
