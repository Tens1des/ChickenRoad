import Foundation

/// Приём ссылки из пуша. Ссылка одноразовая и живёт только в памяти: режим и
/// кэш она не меняет никогда.
final class PushInbox {
    static let shared = PushInbox()
    static let didAcceptLink = Notification.Name("HenPathShell.pushInbox.didAcceptLink")

    private let gate = NSLock()
    private var pendingLink: URL?

    private init() {}

    /// Ссылка читается двумя путями — верхним `url` и вложенным `data.url`.
    /// Оба живые: один ключ покрывает половину случаев, и симптом обманчив —
    /// пуш приходит, тап работает, витрина открывается, просто не та страница.
    @discardableResult
    func accept(userInfo: [AnyHashable: Any]) -> Bool {
        let rawLink = (userInfo["url"] as? String)
            ?? ((userInfo["data"] as? [String: Any])?["url"] as? String)

        guard
            let rawLink = rawLink?.trimmingCharacters(in: .whitespacesAndNewlines),
            !rawLink.isEmpty,
            let link = URL(string: rawLink),
            let scheme = link.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            link.host != nil
        else {
            return false
        }

        gate.lock()
        pendingLink = link
        gate.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.didAcceptLink,
                object: self,
                userInfo: ["url": link]
            )
        }
        return true
    }

    func consume() -> URL? {
        gate.lock()
        defer { gate.unlock() }
        defer { pendingLink = nil }
        return pendingLink
    }
}
