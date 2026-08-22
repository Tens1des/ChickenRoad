import UIKit
import UserNotifications

/// Политика показа кастомного экрана уведомлений и обращение к системному
/// диалогу.
struct ConsentGate {
    /// Повтор не раньше трёх суток: 71:59:59 — нет, 72:00:00 — да.
    static let retryDelay: TimeInterval = 3 * 24 * 60 * 60

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Системный отказ закрывает вопрос навсегда: статус перестаёт быть
    /// `notDetermined`, и ни кастомный экран, ни системный больше не всплывают.
    func shouldPrompt(skippedAt: Date?, now: Date = Date()) async -> Bool {
#if DEBUG
        // Приёмка: пропуск кастомного экрана уведомлений.
        //
        //     -ShellSkipConsent
        if ProcessInfo.processInfo.arguments.contains("-ShellSkipConsent") {
            return false
        }
#endif
        guard await authorizationStatus() == .notDetermined else { return false }
        guard let skippedAt else { return true }
        return now.timeIntervalSince(skippedAt) >= Self.retryDelay
    }

    @MainActor
    func requestSystemAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            UIApplication.shared.registerForRemoteNotifications()
            return granted
        } catch {
            return false
        }
    }
}
