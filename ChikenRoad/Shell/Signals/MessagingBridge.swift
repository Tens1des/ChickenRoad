import Foundation
import OSLog
import UIKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
@preconcurrency import FirebaseMessaging
#endif

/// Мост к Firebase Messaging: настройка вручную, без swizzling.
///
/// Без `GoogleService-Info.plist` приложение не падает: мост просто остаётся
/// ненастроенным, а поля Firebase не уезжают в заявку. SDK подключается при
/// вживлении в игру, поэтому обращения к нему закрыты `#if canImport`.
final class MessagingBridge: NSObject, @unchecked Sendable {
    static let shared = MessagingBridge()
    static let tokenDidChange = Notification.Name("HenPathShell.messaging.tokenDidChange")

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HenPathShell",
        category: "Messaging"
    )
    private let gate = NSLock()
    private var storedToken: String?
    private var ready = false

    private override init() {
        super.init()
    }

    var isReady: Bool {
        gate.withLock { ready }
    }

    var currentToken: String? {
        gate.withLock { storedToken }
    }

    var projectID: String? {
        guard isReady else { return nil }
#if canImport(FirebaseCore)
        return FirebaseApp.app()?.options.projectID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .valueIfFilled
#else
        return nil
#endif
    }

    @MainActor
    func configure(application: UIApplication) {
        guard !isReady else { return }

        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            logger.notice("GoogleService-Info.plist is absent; Firebase fields will be omitted")
            return
        }

#if canImport(FirebaseCore) && canImport(FirebaseMessaging)
        FirebaseApp.configure()
        gate.withLock { ready = true }

        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true

        // Регистрация в APNs сама по себе алерт разрешения не показывает.
        // Благодаря этому токен FCM успевает появиться до кастомного экрана.
        application.registerForRemoteNotifications()
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                self?.logger.error("Initial FCM token request failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            self?.store(token: token)
        }
#else
        logger.notice("Firebase SDK is absent; push token will not be requested")
#endif
    }

    func setAPNSToken(_ token: Data) {
        guard isReady else { return }
#if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = token
#endif
    }

    func receiveRemoteMessage(_ userInfo: [AnyHashable: Any]) {
        guard isReady else { return }
#if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
#endif
    }

    func tokenSnapshot(waitUpTo seconds: TimeInterval = 2) async -> String? {
        if let currentToken { return currentToken }
        guard isReady, seconds > 0 else { return nil }

        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if let currentToken { return currentToken }
        }
        return currentToken
    }

    private func store(token: String?) {
        let normalized = token?.trimmingCharacters(in: .whitespacesAndNewlines).valueIfFilled
        let changed = gate.withLock { () -> Bool in
            guard storedToken != normalized else { return false }
            storedToken = normalized
            return true
        }

        guard changed else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.tokenDidChange,
                object: self,
                userInfo: normalized.map { ["token": $0] }
            )
        }
    }
}

#if canImport(FirebaseMessaging)
extension MessagingBridge: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        store(token: fcmToken)
    }
}
#endif

private extension String {
    var valueIfFilled: String? {
        isEmpty ? nil : self
    }
}
