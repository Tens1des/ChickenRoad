import Foundation

/// Сборка тела заявки: поля атрибуции плюс пять ключей приложения.
struct ExchangeEnvelope: Sendable {
    init() {}

    /// Пять контрактных ключей кладутся **поверх** атрибуции и намеренно
    /// перекрывают одноимённые поля из SDK.
    ///
    /// Опциональные поля при пустом значении не пропускаются, а удаляются:
    /// иначе устаревшее значение, приехавшее из атрибуции, молча уедет на сервер.
    func seal(
        attribution: [String: Any],
        appsFlyerUID: String,
        bundleIdentifier: String,
        storeID: String,
        locale: Locale = .current,
        pushToken: String? = nil,
        firebaseProjectID: String? = nil
    ) throws -> [String: Any] {
        let afID = appsFlyerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let contractStoreID = Self.contractStoreID(storeID)

        guard !afID.isEmpty else { throw EnvelopeError.missingContractValue("af_id") }
        guard !bundleID.isEmpty else { throw EnvelopeError.missingContractValue("bundle_id") }
        guard let contractStoreID else { throw EnvelopeError.missingContractValue("store_id") }

        var body = attribution
        body["af_id"] = afID
        body["bundle_id"] = bundleID
        body["os"] = "iOS"
        body["store_id"] = contractStoreID
        body["locale"] = Self.rfc3066(locale)

        if let value = Self.filled(pushToken) {
            body["push_token"] = value
        } else {
            body.removeValue(forKey: "push_token")
        }
        if let value = Self.filled(firebaseProjectID) {
            body["firebase_project_id"] = value
        } else {
            body.removeValue(forKey: "firebase_project_id")
        }

        // Значения SDK не приводятся к типам и не выбрасываются поштучно:
        // непригодное к JSON тело отклоняется целиком, до сети, и экран
        // остаётся повторяемым.
        guard JSONSerialization.isValidJSONObject(body) else {
            throw EnvelopeError.valueNotRepresentableInJSON
        }
        return body
    }

    private static func contractStoreID(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.lowercased().hasPrefix("id") ? String(trimmed.dropFirst(2)) : trimmed
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return "id\(digits)"
    }

    private static func filled(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func rfc3066(_ locale: Locale) -> String {
        let base = locale.identifier.split(separator: "@", maxSplits: 1).first.map(String.init)
            ?? locale.identifier
        return base.replacingOccurrences(of: "_", with: "-")
    }
}
