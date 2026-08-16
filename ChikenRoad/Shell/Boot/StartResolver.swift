import Foundation

/// Почему понадобился поход к серверу. Влияет только на диагностику, не на
/// исход: ветку решает `StartAction`.
enum ExchangeReason: Equatable {
    case firstDecision
    case grantExpired
    case grantMissing
    case pushTokenRotated
}

enum StartAction: Equatable {
    case awaitReachability
    case handOverToGame
    case reportOffline
    case openGrant(LinkGrant)
    case exchange(reason: ExchangeReason, fallback: LinkGrant?)
}

/// Политика запуска целиком: чистая функция без сети, часов и контейнера.
///
/// `now` и `forceRefresh` приходят параметрами именно для того, чтобы вся
/// таблица режимов проверялась тестами напрямую.
enum StartResolver {
    static func resolve(
        mode: ShellMode,
        grant: LinkGrant?,
        reachability: ReachabilityProbe.State,
        now: Date = Date(),
        forceRefresh: Bool = false
    ) -> StartAction {
        // Native — установочный лок: он сильнее связности, кэша и refresh-а.
        if mode == .native {
            return .handOverToGame
        }

        switch reachability {
        case .checking:
            return .awaitReachability
        case .offline:
            return .reportOffline
        case .online:
            break
        }

        if mode == .undecided {
            return .exchange(reason: .firstDecision, fallback: nil)
        }

        if forceRefresh {
            return .exchange(reason: .pushTokenRotated, fallback: grant)
        }

        guard let grant else {
            return .exchange(reason: .grantMissing, fallback: nil)
        }

        if grant.hasExpired(at: now) {
            return .exchange(reason: .grantExpired, fallback: grant)
        }

        return .openGrant(grant)
    }
}
