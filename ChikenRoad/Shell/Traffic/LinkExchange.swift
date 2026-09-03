import Foundation

/// Единственный поход серого слоя в сеть.
final class LinkExchange: @unchecked Sendable {
    private let transport: URLSession
    private let deadline: TimeInterval

    init(deadline: TimeInterval = 15) {
        let setup = URLSessionConfiguration.ephemeral
        setup.timeoutIntervalForRequest = deadline
        setup.timeoutIntervalForResource = deadline
        setup.requestCachePolicy = .reloadIgnoringLocalCacheData
        setup.urlCache = nil
        self.transport = URLSession(configuration: setup)
        self.deadline = deadline
    }

    init(transport: URLSession, deadline: TimeInterval = 15) {
        self.transport = transport
        self.deadline = deadline
    }

    func ask(endpoint: URL, envelope: [String: Any]) async throws -> ExchangeReceipt {
        guard let scheme = endpoint.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              endpoint.host != nil else {
            throw LinkExchangeError.unusableEndpoint
        }
        guard JSONSerialization.isValidJSONObject(envelope) else {
            throw LinkExchangeError.unusableEnvelope
        }

        var request = URLRequest(url: endpoint, timeoutInterval: deadline)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: envelope)

        let body: Data
        let response: URLResponse
        do {
            (body, response) = try await transport.data(for: request)
        } catch let error as URLError {
            throw LinkExchangeError.transport(code: error.code)
        } catch {
            throw LinkExchangeError.transport(code: .unknown)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LinkExchangeError.noHTTPResponse
        }
        // Любой не-200 — отказ, и тело при этом не разбирается вообще.
        guard http.statusCode == 200 else {
            return ExchangeReceipt(
                verdict: .declined,
                answeredOverHTTP: true,
                statusCode: http.statusCode
            )
        }

        guard let object = try? JSONSerialization.jsonObject(with: body),
              let fields = object as? [String: Any],
              let ok = Self.strictBoolean(fields["ok"]) else {
            throw LinkExchangeError.unreadableBody(statusCode: http.statusCode)
        }
        guard ok else {
            return ExchangeReceipt(verdict: .declined, answeredOverHTTP: true, statusCode: http.statusCode)
        }

        guard let rawLink = fields["url"] as? String,
              let parsed = URL(string: rawLink),
              let linkScheme = parsed.scheme?.lowercased(),
              linkScheme == "http" || linkScheme == "https",
              parsed.host != nil else {
            throw LinkExchangeError.unusableGrant(statusCode: http.statusCode)
        }

        // Срок годности не решает, выдана ссылка или нет.
        //
        // По ТЗ §1.1 положительный ответ со ссылкой — это витрина, и негодный
        // `expires` (строка, ноль, отсутствует) отменить выдачу не может. Такой
        // грант сохраняется просроченным: витрина открывается сейчас, а
        // следующий запуск идёт за свежей ссылкой — ровно ветка «истёк» из §1.2.
        //
        // Раньше он летел в `unusableGrant`, а с тех пор как не-200 перестал
        // разбираться отдельно, оттуда — в `sealNative()`. То есть выданная
        // сервером ссылка навсегда теряла установку в игре.
        var expires: TimeInterval = 0
        if let stamped = Self.epoch(fields["expires"]), stamped.isFinite, stamped > 0 {
            expires = stamped
        }

        return ExchangeReceipt(
            verdict: .granted(LinkGrant(rawLink: rawLink, expiresEpoch: expires)),
            answeredOverHTTP: true,
            statusCode: http.statusCode
        )
    }

    /// Только настоящий булев. `1`, `"true"` и `"yes"` разрешением не считаются:
    /// упрощение до `as? Bool` пропустило бы `NSNumber(1)` и превратило отказ
    /// сервера в согласие.
    private static func strictBoolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func epoch(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber,
           CFGetTypeID(number) != CFBooleanGetTypeID() {
            return number.doubleValue
        }
        if let text = value as? String {
            return TimeInterval(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
