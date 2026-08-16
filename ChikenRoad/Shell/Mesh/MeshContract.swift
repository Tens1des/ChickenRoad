import Foundation

/// Что сейчас на экране. Единственная величина, которую серый слой показывает
/// наружу.
enum ShellDestination: Equatable {
    case loading
    case offline
    case recoverableFailure(String)
    case setupRequired(String)
    case consent(URL)
    case web(URL)
    case game
}

/// Общий контракт узлов сети.
///
/// Узлы не держат ссылок друг на друга — только на контекст, который реализует
/// фасад. За счёт этого разрез координатора на четыре части не превращается в
/// четыре взаимных зависимости.
@MainActor
protocol MeshContext: AnyObject {
    var vault: ShellVault { get }
    var settings: ShellSettings? { get }
    var settingsFailure: Error? { get }
    var startupFailure: Error? { get }

    var reachability: ReachabilityProbe { get }
    var messaging: MessagingBridge { get }
    var signature: InstallSignature { get }
    var inbox: PushInbox { get }
    var consentGate: ConsentGate { get }
    var envelope: ExchangeEnvelope { get }
    var linkExchange: LinkExchange { get }

    var destination: ShellDestination { get }
    /// Поднимает подписки узлов. Вызывается до чтения режима установки: иначе на
    /// вечном native перестанет работать маршрутизация пуша.
    func observeSignals()
    func show(_ destination: ShellDestination)
    func showWeb(_ url: URL)
    func armLoadingDeadline()
    func keepsVisibleWebDuringRefresh(fallback: LinkGrant?) -> Bool

    /// Читается синхронно из четырёх разных мест. Асинхронный доступ или копия
    /// значения в соседнем узле создают гонку, и пуш перекрывается загрузкой.
    var oneShotPushLink: URL? { get }
    func adoptOneShotPushLink(_ url: URL)

    func scheduleExchange(forceRefresh: Bool)
    func presentPersistentWeb(_ url: URL) async
}
