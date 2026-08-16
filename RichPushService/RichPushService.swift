import UserNotifications
@preconcurrency import FirebaseMessaging

/// Rich push: расширение забирает у Firebase вложение и отдаёт готовое
/// уведомление.
///
/// По таймауту система отбирает управление. Отдать в этот момент нечего —
/// значит показать пустое уведомление, поэтому наготове всегда лежит текст
/// исходной заявки.
final class RichPushService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler

        guard let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            finish(with: request.content)
            return
        }

        bestAttemptContent = mutableContent
        Messaging.serviceExtension().populateNotificationContent(mutableContent) { [weak self] content in
            self?.finish(with: content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        guard let bestAttemptContent else { return }
        finish(with: bestAttemptContent)
    }

    private func finish(with content: UNNotificationContent) {
        guard let contentHandler else { return }
        self.contentHandler = nil
        contentHandler(content)
    }
}
