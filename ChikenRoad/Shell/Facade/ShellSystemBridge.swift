import Foundation
import OSLog
import UIKit
import UserNotifications

/// Делегат приложения: APNs-токен, фоновые пуши, universal links.
///
/// Разговаривает только с фасадом — до контейнера и узлов отсюда хода нет.
final class ShellSystemBridge: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HenPathShell",
        category: "SystemBridge"
    )

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        MainActor.assumeIsolated {
            let shell = AppShellFacade.shared
            shell.bootstrap(application: application, launchOptions: launchOptions)

            if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
                shell.receiveRemoteMessage(userInfo)
                shell.acceptPushPayload(userInfo)
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated {
            AppShellFacade.shared.supportedOrientations
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        MainActor.assumeIsolated {
            AppShellFacade.shared.setAPNSToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        MainActor.assumeIsolated {
            AppShellFacade.shared.receiveRemoteMessage(userInfo)
        }
        completionHandler(.newData)
    }

    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        AppShellFacade.shared.receiveRemoteMessage(notification.request.content.userInfo)
        return [.banner, .list, .sound]
    }

    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let shell = AppShellFacade.shared
        shell.receiveRemoteMessage(userInfo)
        shell.acceptPushPayload(userInfo)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        MainActor.assumeIsolated {
            AppShellFacade.shared.handleOpen(url, options: options)
        }
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        MainActor.assumeIsolated {
            AppShellFacade.shared.continueUserActivity(userActivity)
        }
    }
}
