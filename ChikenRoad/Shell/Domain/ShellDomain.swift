import Foundation

/// Установочный режим. Решение принимается один раз, лежит в хранилище и
/// переживает перезапуск: `web` и `native` — это лок, а не подсказка.
enum ShellMode: String, Codable, Sendable {
    case undecided
    case web
    case native
}

/// Выданная сервером ссылка вместе со сроком годности.
///
/// Строка хранится ровно такой, какой приехала: query, fragment и
/// percent-encoding обязаны совпасть побайтно после ответа, после кэша и после
/// перезапуска, поэтому здесь нет ни `URLComponents`, ни повторного кодирования.
struct LinkGrant: Equatable, Codable, Sendable {
    let rawLink: String
    let expiresEpoch: TimeInterval

    init(rawLink: String, expiresEpoch: TimeInterval) {
        self.rawLink = rawLink
        self.expiresEpoch = expiresEpoch
    }

    var destination: URL? { URL(string: rawLink) }

    /// Ровно `now` уже истёк, `now + 1` ещё жив.
    func hasExpired(at moment: Date = Date()) -> Bool {
        expiresEpoch <= moment.timeIntervalSince1970
    }
}

/// Как сервер ответил по существу: выдал ссылку или отказал.
enum ExchangeVerdict: Equatable, Sendable {
    case granted(LinkGrant)
    case declined
}

/// Результат обмена целиком. `answeredOverHTTP` отделяет «сервер ответил» от
/// «связь оборвалась»: только по первому засчитывается доставка push-токена.
struct ExchangeReceipt: Equatable, Sendable {
    let verdict: ExchangeVerdict
    let answeredOverHTTP: Bool
    let statusCode: Int

    init(verdict: ExchangeVerdict, answeredOverHTTP: Bool, statusCode: Int) {
        self.verdict = verdict
        self.answeredOverHTTP = answeredOverHTTP
        self.statusCode = statusCode
    }
}

enum LinkExchangeError: Error, Equatable, Sendable {
    case unusableEndpoint
    case unusableEnvelope
    case transport(code: URLError.Code)
    case noHTTPResponse
    case unreadableBody(statusCode: Int)
    case unusableGrant(statusCode: Int)

    /// Сервер всё-таки ответил — тело просто оказалось непригодным.
    var answeredOverHTTP: Bool {
        switch self {
        case .unreadableBody, .unusableGrant: return true
        default: return false
        }
    }
}

enum EnvelopeError: Error, Equatable, Sendable {
    case missingContractValue(String)
    case valueNotRepresentableInJSON
}
