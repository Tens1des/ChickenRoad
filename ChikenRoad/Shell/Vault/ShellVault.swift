import Foundation

/// Единственное место, где серый слой что-то помнит между запусками.
///
/// Префикс ключей взят от идентификатора приложения. Миграции не нужно:
/// серого слоя в этой сборке раньше не было, установленной базы с другими
/// ключами не существует.
final class ShellVault: @unchecked Sendable {
    private enum Slot {
        static let mode = "henpath.shell.mode"
        static let linkURL = "henpath.shell.link_url"
        static let linkExpires = "henpath.shell.link_expires"
        static let consentSkippedAt = "henpath.shell.consent_skipped_at"
        static let deliveredPushToken = "henpath.shell.delivered_push_token"
    }

    private let store: UserDefaults
    private let gate = NSLock()

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    var installMode: ShellMode {
        gate.withLock {
            guard let raw = store.string(forKey: Slot.mode) else { return .undecided }
            return ShellMode(rawValue: raw) ?? .undecided
        }
    }

    /// Половинчатая запись не выдаётся наружу: ссылка без срока — это не грант.
    var storedGrant: LinkGrant? {
        gate.withLock {
            guard let rawLink = store.string(forKey: Slot.linkURL),
                  store.object(forKey: Slot.linkExpires) != nil else { return nil }
            return LinkGrant(
                rawLink: rawLink,
                expiresEpoch: store.double(forKey: Slot.linkExpires)
            )
        }
    }

    var consentSkippedAt: Date? {
        get { gate.withLock { store.object(forKey: Slot.consentSkippedAt) as? Date } }
        set { gate.withLock { store.set(newValue, forKey: Slot.consentSkippedAt) } }
    }

    var deliveredPushToken: String? {
        get { gate.withLock { store.string(forKey: Slot.deliveredPushToken) } }
        set { gate.withLock { store.set(newValue, forKey: Slot.deliveredPushToken) } }
    }

    func sealWeb(_ grant: LinkGrant) {
        gate.withLock {
            // Прерванная запись может остаться undecided, но никогда не станет
            // web без своей сессии: режим пишется последним.
            store.set(grant.rawLink, forKey: Slot.linkURL)
            store.set(grant.expiresEpoch, forKey: Slot.linkExpires)
            store.set(ShellMode.web.rawValue, forKey: Slot.mode)
        }
    }

    func sealNative() {
        gate.withLock {
            store.removeObject(forKey: Slot.linkURL)
            store.removeObject(forKey: Slot.linkExpires)
            store.set(ShellMode.native.rawValue, forKey: Slot.mode)
        }
    }

    var permitsExchange: Bool { installMode != .native }
}
