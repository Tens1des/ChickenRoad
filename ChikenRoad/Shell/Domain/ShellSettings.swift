import Foundation

/// Конфигурация серого слоя, прочитанная из бандла.
///
/// Валидация строгая и нарочно недоверчивая: невалидный конфиг обязан честно
/// привести к экрану `Configuration Required`, а не к правдоподобному запросу с
/// плейсхолдером внутри.
struct ShellSettings: Equatable, Sendable {
    let exchangeEndpoint: URL
    let attributionDevKey: String
    let appleAppID: String
    let storeID: String
    let privacyPolicyURL: URL
    let externalSchemes: Set<String>

    static func load(
        from bundle: Bundle = .main,
        resourceName: String = "ShellConfig"
    ) throws -> ShellSettings {
        guard let url = bundle.url(forResource: resourceName, withExtension: "plist") else {
            throw ShellSettingsError.missingResource("\(resourceName).plist")
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ShellSettingsError.unreadableResource
        }

        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw ShellSettingsError.invalidPropertyList
        }

        guard let values = object as? [String: Any] else {
            throw ShellSettingsError.invalidPropertyList
        }

        let endpointText = try requiredText("LinkEndpoint", aliases: ["linkEndpoint"], in: values)
        let devKey = try requiredText("AttributionDevKey", aliases: ["attributionDevKey"], in: values)
        let rawAppleID = try requiredText("AppleAppID", aliases: ["appleAppID"], in: values)
        let rawStoreID = try optionalText("StoreID", aliases: ["storeID"], in: values) ?? rawAppleID
        let privacyText = try requiredText("PrivacyPolicyURL", aliases: ["privacyPolicyURL"], in: values)
        let schemes = try textArray("AllowedExternalSchemes", aliases: ["allowedExternalSchemes"], in: values)

        guard let bundleIdentifier = bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty else {
            throw ShellSettingsError.invalidValue("bundleIdentifier")
        }
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        guard !normalizedBundleIdentifier.hasPrefix("com.example."),
              !normalizedBundleIdentifier.hasPrefix("org.example."),
              !isPlaceholder(bundleIdentifier) else {
            throw ShellSettingsError.placeholderValue("bundleIdentifier")
        }

        guard let endpoint = webURL(endpointText) else {
            throw ShellSettingsError.invalidURL(key: "LinkEndpoint")
        }
        guard let privacyURL = webURL(privacyText) else {
            throw ShellSettingsError.invalidURL(key: "PrivacyPolicyURL")
        }

        let appleIDDigits = digits(of: rawAppleID)
        guard !appleIDDigits.isEmpty, appleIDDigits.allSatisfy(\.isNumber) else {
            throw ShellSettingsError.invalidAppleAppID
        }
        guard appleIDDigits.contains(where: { $0 != "0" }) else {
            throw ShellSettingsError.placeholderValue("AppleAppID")
        }

        let storeIDDigits = digits(of: rawStoreID)
        guard !storeIDDigits.isEmpty, storeIDDigits.allSatisfy(\.isNumber) else {
            throw ShellSettingsError.invalidValue("StoreID")
        }
        guard storeIDDigits.contains(where: { $0 != "0" }) else {
            throw ShellSettingsError.placeholderValue("StoreID")
        }

        let normalizedSchemes = try Set(schemes.map { scheme in
            let value = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !isPlaceholder(value), isValidScheme(value) else {
                throw ShellSettingsError.invalidExternalScheme(scheme)
            }
            return value
        })

        return ShellSettings(
            exchangeEndpoint: endpoint,
            attributionDevKey: devKey,
            appleAppID: appleIDDigits,
            storeID: "id\(storeIDDigits)",
            privacyPolicyURL: privacyURL,
            externalSchemes: normalizedSchemes
        )
    }
}

#if DEBUG
extension ShellSettings {
    /// Приёмочная подмена адреса конфига. В релиз не попадает.
    ///
    ///     -ShellConfigEndpoint http://127.0.0.1:8788/config
    ///
    /// Боевой эндпоинт отвечает либо ссылкой, либо отказом, и выбирать нечем:
    /// сценарии первого запуска, срока годности ссылки и экрана уведомлений
    /// требуют обеих веток подряд, на одной установке. Подменяется **только**
    /// адрес — разбор ответа, лок режима и весь остальной путь остаются боевыми.
    func overridingEndpointFromLaunchArguments() -> ShellSettings {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ShellConfigEndpoint"),
              arguments.indices.contains(index + 1),
              let replacement = Self.webURL(arguments[index + 1]) else {
            return self
        }
        return ShellSettings(
            exchangeEndpoint: replacement,
            attributionDevKey: attributionDevKey,
            appleAppID: appleAppID,
            storeID: storeID,
            privacyPolicyURL: privacyPolicyURL,
            externalSchemes: externalSchemes
        )
    }
}
#endif

enum ShellSettingsError: Error, Equatable, LocalizedError {
    case missingResource(String)
    case unreadableResource
    case invalidPropertyList
    case missingValue(String)
    case invalidValue(String)
    case placeholderValue(String)
    case invalidURL(key: String)
    case invalidAppleAppID
    case invalidExternalScheme(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Missing bundled configuration resource: \(name)."
        case .unreadableResource: return "The bundled configuration cannot be read."
        case .invalidPropertyList: return "The bundled configuration is not a valid property list."
        case .missingValue(let key): return "Missing configuration value: \(key)."
        case .invalidValue(let key): return "Invalid configuration value: \(key)."
        case .placeholderValue(let key): return "Configuration value is still a placeholder: \(key)."
        case .invalidURL(let key): return "Configuration URL is invalid: \(key)."
        case .invalidAppleAppID: return "AppleAppID must contain an App Store numeric identifier."
        case .invalidExternalScheme(let scheme): return "Invalid external URL scheme: \(scheme)."
        }
    }
}

private extension ShellSettings {
    static func requiredText(
        _ key: String,
        aliases: [String] = [],
        in values: [String: Any]
    ) throws -> String {
        guard let raw = ([key] + aliases).lazy.compactMap({ values[$0] as? String }).first else {
            throw ShellSettingsError.missingValue(key)
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ShellSettingsError.invalidValue(key) }
        guard !isPlaceholder(value) else { throw ShellSettingsError.placeholderValue(key) }
        return value
    }

    static func optionalText(
        _ key: String,
        aliases: [String] = [],
        in values: [String: Any]
    ) throws -> String? {
        guard let raw = ([key] + aliases).lazy.compactMap({ values[$0] }).first else { return nil }
        guard let text = raw as? String else { throw ShellSettingsError.invalidValue(key) }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ShellSettingsError.invalidValue(key) }
        guard !isPlaceholder(value) else { throw ShellSettingsError.placeholderValue(key) }
        return value
    }

    static func textArray(
        _ key: String,
        aliases: [String] = [],
        in values: [String: Any]
    ) throws -> [String] {
        guard let raw = ([key] + aliases).lazy.compactMap({ values[$0] }).first else {
            throw ShellSettingsError.missingValue(key)
        }
        guard let result = raw as? [String] else { throw ShellSettingsError.invalidValue(key) }
        return result
    }

    static func digits(of value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased().hasPrefix("id") ? String(trimmed.dropFirst(2)) : trimmed
    }

    static func webURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    static func isValidScheme(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first,
              CharacterSet.letters.contains(first) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+-."))
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    static func isPlaceholder(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return lowered.contains("${")
            || lowered.contains("<")
            || lowered.contains(">")
            || lowered.contains("your_")
            || lowered.contains("your-")
            || lowered.contains("replace_me")
            || lowered.contains("replace-me")
            || lowered.contains("placeholder")
            || lowered.contains("example.com")
    }
}
