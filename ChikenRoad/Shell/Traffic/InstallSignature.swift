import Foundation
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
import OSLog
import UIKit
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

enum InstallSignatureError: Error, Equatable, Sendable {
    case invalidCredentials
    case alreadyInitialized
    case notInitialized
}

/// Атрибуция установки: серый слой её только **забирает** и отдаёт конфигу.
/// Событий в AppsFlyer он не шлёт.
///
/// SDK подключается на этапе вживления в игру, поэтому весь доступ к нему
/// закрыт `#if canImport(AppsFlyerLib)`. Без пакета слой компилируется и ведёт
/// себя нейтрально: подписи нет, ожидание колбэков не висит.
final class InstallSignature: NSObject, @unchecked Sendable {
    private let ledger = SignatureLedger()
    private let damper = DeliveryDamper()
    private let lifecycleLock = NSLock()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HenPathShell",
        category: "Attribution"
    )
    private var credentials: (devKey: String, appID: String)?

    override init() {
        super.init()
#if !canImport(AppsFlyerLib)
        // Без SDK колбэков не будет вообще, и ожидание снимка обязано
        // завершиться сразу, а не съесть свои три секунды на пустом месте.
        ledger.markConversionSettled()
        ledger.markDeepLinkSettled()
#endif
    }

    func initialize(devKey: String, appId: String) throws {
        let cleanDevKey = devKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAppID: String = {
            let value = appId.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.lowercased().hasPrefix("id") ? String(value.dropFirst(2)) : value
        }()
        guard !cleanDevKey.isEmpty,
              !cleanAppID.isEmpty,
              cleanAppID.allSatisfy(\.isNumber) else {
            throw InstallSignatureError.invalidCredentials
        }

        lifecycleLock.lock()
        if let credentials {
            lifecycleLock.unlock()
            if credentials.devKey == cleanDevKey, credentials.appID == cleanAppID { return }
            throw InstallSignatureError.alreadyInitialized
        }
        credentials = (cleanDevKey, cleanAppID)
        lifecycleLock.unlock()

#if canImport(AppsFlyerLib)
        let sdk = AppsFlyerLib.shared()
        sdk.initialize(devKey: cleanDevKey, appId: cleanAppID)
        sdk.delegate = self
        sdk.deepLinkDelegate = self
#else
        logger.notice("AppsFlyer SDK is absent; attribution fields will be omitted")
#endif
    }

    func handleLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) throws {
        try ensureInitialized()
#if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleLaunchOptions(launchOptions)
#endif
    }

    func registerSessionReadyListener(
        startAutomatically: Bool = true,
        onReady: (@Sendable () -> Void)? = nil
    ) throws {
        try ensureInitialized()
#if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().registerSessionReadyListener {
            onReady?()
            guard startAutomatically else { return }
            Self.authorizeTrackingThenStart()
        }
#endif
    }

#if canImport(AppsFlyerLib)
    /// Спросить ATT и только потом отдать сессию.
    ///
    /// Без этого IDFA обнулён, и `advertising_id` из трекинговой ссылки не с чем
    /// склеить — установка приезжает органической, сколько ни жди конверсию.
    /// ATT не входит в условия готовности сессии, поэтому спрашиваем здесь, в
    /// самом листенере, а не в `didFinishLaunching`.
    private static func authorizeTrackingThenStart() {
        let gate = NSLock()
        var launched = false
        let launch: @Sendable () -> Void = {
            gate.lock()
            let first = !launched
            launched = true
            gate.unlock()
            if first { AppsFlyerLib.shared().start() }
        }

#if canImport(AppTrackingTransparency)
        if #available(iOS 14.5, *) {
            // Диалог показывается только активному приложению: на `.inactive`
            // запрос молча вернёт `.notDetermined`, и IDFA не появится.
            whenActive {
                ATTrackingManager.requestTrackingAuthorization { _ in launch() }
            }
            // Потолок: сессия обязана уйти, даже если диалога не случилось
            // вовсе — иначе атрибуции не будет совсем.
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { launch() }
            return
        }
#endif
        launch()
    }

    private static func whenActive(_ work: @escaping @Sendable () -> Void) {
        if UIApplication.shared.applicationState == .active {
            work()
            return
        }
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            if let token { NotificationCenter.default.removeObserver(token) }
            work()
        }
    }
#endif

    func start() throws {
        try ensureInitialized()
#if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().start()
#endif
    }

    func unregisterSessionReadyListener() {
        guard isInitialized else { return }
#if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().unregisterSessionReadyListener()
#endif
    }

    var installID: String {
        guard isInitialized else { return "" }
#if canImport(AppsFlyerLib)
        return AppsFlyerLib.shared().getAppsFlyerUID()
#else
        return ""
#endif
    }

    @discardableResult
    func handleOpen(
        _ url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard isInitialized else { return false }
        guard damper.shouldForward(url, source: .applicationOpen) else { return true }
#if canImport(AppsFlyerLib)
        let erasedOptions = Dictionary(uniqueKeysWithValues: options.map { (AnyHashable($0.key), $0.value) })
        AppsFlyerLib.shared().handleOpen(url, options: erasedOptions)
#endif
        return true
    }

    @discardableResult
    func handleOpenFromScene(_ url: URL) -> Bool {
        guard isInitialized else { return false }
        guard damper.shouldForward(url, source: .scene) else { return true }
#if canImport(AppsFlyerLib)
        // Универсальная ссылка и кастомная схема — разные входы SDK. Схему,
        // отданную в `handleUniversalLink`, AppsFlyer не резолвит, и диплинк
        // теряется вместе с атрибуцией.
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            AppsFlyerLib.shared().handleUniversalLink(url)
        } else {
            AppsFlyerLib.shared().handleOpen(url, options: [:])
        }
#endif
        return true
    }

    @discardableResult
    func `continue`(_ userActivity: NSUserActivity) -> Bool {
        guard isInitialized else { return false }
        if let url = userActivity.webpageURL,
           !damper.shouldForward(url, source: .userActivity) {
            return true
        }
#if canImport(AppsFlyerLib)
        return AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
#else
        return false
#endif
    }

    /// Конверсия и UDL ждутся вместе, не по очереди.
    func snapshot(waitingUpTo timeout: TimeInterval = 3) async -> [String: Any] {
        await ledger.snapshot(waitingUpTo: max(0, timeout))
    }

    /// Пришли ли уже оба колбэка SDK. Нужно, чтобы отличить «атрибуция сказала
    /// Organic» от «атрибуция не успела»: во втором случае отказ сервера — наш
    /// промах, и фиксировать по нему режим навсегда нельзя.
    var isAttributionSettled: Bool { ledger.isSettled }

    private func ensureInitialized() throws {
        guard isInitialized else { throw InstallSignatureError.notInitialized }
    }

    private var isInitialized: Bool {
        lifecycleLock.lock()
        let initialized = credentials != nil
        lifecycleLock.unlock()
        return initialized
    }
}

#if canImport(AppsFlyerLib)
extension InstallSignature: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        ledger.mergeConversion(conversionInfo)
        ledger.markConversionSettled()
    }

    func onConversionDataFail(_ error: Error) {
        ledger.markConversionSettled()
    }
}

extension InstallSignature: AppsFlyerDeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        switch result.status {
        case .found:
            if let clickEvent = result.deepLink?.clickEvent {
                ledger.mergeClickEvent(clickEvent)
            }
            ledger.markDeepLinkSettled()
        case .failure, .notFound:
            ledger.markDeepLinkSettled()
        @unknown default:
            ledger.markDeepLinkSettled()
        }
    }
}
#endif

private enum DeliveryChannel: Equatable {
    case applicationOpen
    case scene
    case userActivity
}

/// Одна и та же ссылка приезжает и в делегат приложения, и в сцену. Схлопывается
/// только этот межканальный дубль — повторное осознанное открытие до SDK доходит.
private final class DeliveryDamper: @unchecked Sendable {
    private struct Delivery {
        let channel: DeliveryChannel
        let timestamp: TimeInterval
    }

    private let gate = NSLock()
    private let window: TimeInterval = 1
    private var recent: [String: Delivery] = [:]

    func shouldForward(_ url: URL, source: DeliveryChannel) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let key = url.absoluteString

        gate.lock()
        defer { gate.unlock() }

        recent = recent.filter { now - $0.value.timestamp <= window }
        if let previous = recent[key], previous.channel != source {
            return false
        }

        recent[key] = Delivery(channel: source, timestamp: now)
        return true
    }
}

/// Копилка полей атрибуции: **первое** полученное значение ключа побеждает.
/// Обратный порядок затирал бы UDL-данные, которые приходят вторыми.
private final class SignatureLedger: @unchecked Sendable {
    private let gate = NSLock()
    /// Ответ конверсии перезаписывается: SDK сначала отдаёт то, что знает, и
    /// уточняет после матчинга. Первое значение здесь — не правда, а черновик.
    private var conversion: [String: Any] = [:]
    /// UDL приходит вторым и обязан побеждать, поэтому здесь первое значение
    /// и остаётся первым.
    private var clickEvent: [String: Any] = [:]
    private var conversionSettled = false
    private var deepLinkSettled = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    func mergeConversion(_ fields: [AnyHashable: Any]) {
        gate.lock()
        for (key, value) in fields {
            guard let textKey = Self.textKey(key) else { continue }
            // Значение SDK не приводится к типу и не выбрасывается: пригодность
            // к JSON проверяется один раз, непосредственно перед запросом.
            conversion[textKey] = value
        }
        gate.unlock()
    }

    func mergeClickEvent(_ fields: [AnyHashable: Any]) {
        gate.lock()
        for (key, value) in fields {
            guard let textKey = Self.textKey(key), clickEvent[textKey] == nil else { continue }
            clickEvent[textKey] = value
        }
        gate.unlock()
    }

    func markConversionSettled() {
        settle { conversionSettled = true }
    }

    func markDeepLinkSettled() {
        settle { deepLinkSettled = true }
    }

    func snapshot(waitingUpTo timeout: TimeInterval) async -> [String: Any] {
        if !isSettled, timeout > 0 {
            let waiterID = UUID()
            await withCheckedContinuation { continuation in
                gate.lock()
                if conversionSettled && deepLinkSettled {
                    gate.unlock()
                    continuation.resume()
                    return
                }
                waiters[waiterID] = continuation
                gate.unlock()

                let nanoseconds = UInt64(min(timeout, 60) * 1_000_000_000)
                Task.detached { [weak self] in
                    try? await Task.sleep(nanoseconds: nanoseconds)
                    self?.resumeWaiter(waiterID)
                }
            }
        }

        return currentValues()
    }

    var isSettled: Bool {
        gate.lock()
        defer { gate.unlock() }
        return conversionSettled && deepLinkSettled
    }

    private func settle(_ update: () -> Void) {
        gate.lock()
        update()
        guard conversionSettled && deepLinkSettled else {
            gate.unlock()
            return
        }
        let continuations = Array(waiters.values)
        waiters.removeAll()
        gate.unlock()
        continuations.forEach { $0.resume() }
    }

    private func resumeWaiter(_ id: UUID) {
        gate.lock()
        let continuation = waiters.removeValue(forKey: id)
        gate.unlock()
        continuation?.resume()
    }

    private func currentValues() -> [String: Any] {
        gate.lock()
        defer { gate.unlock() }
        // UDL поверх конверсии — прежний приоритет: диплинк приходит вторым и
        // обязан побеждать одноимённые поля конверсии.
        return conversion.merging(clickEvent) { _, deepLink in deepLink }
    }

    private static func textKey(_ key: AnyHashable) -> String? {
        if let value = key.base as? String { return value }
        if let value = key.base as? NSString { return value as String }
        return nil
    }
}
