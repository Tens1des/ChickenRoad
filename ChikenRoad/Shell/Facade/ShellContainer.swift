import Foundation
import UIKit

/// Композиция зависимостей серого слоя. Наружу не торчит: с ней разговаривает
/// только фасад.
@MainActor
final class ShellContainer {
    static let shared = ShellContainer()

    let vault: ShellVault
    let signature: InstallSignature
    let envelope: ExchangeEnvelope
    let linkExchange: LinkExchange
    let reachability: ReachabilityProbe
    let messaging: MessagingBridge
    let inbox: PushInbox
    let consentGate: ConsentGate

    private(set) var settingsResult: Result<ShellSettings, Error>
    private(set) var startupFailure: Error?
    private var bootstrapped = false

    private init() {
        vault = ShellVault()
        signature = InstallSignature()
        envelope = ExchangeEnvelope()
        // Транспортный таймаут 6 с; отдельный дедлайн видимой загрузки — 10 с.
        linkExchange = LinkExchange(deadline: 6)
        reachability = ReachabilityProbe()
        messaging = .shared
        inbox = .shared
        consentGate = ConsentGate()

        do {
            let loaded = try ShellSettings.load()
#if DEBUG
            settingsResult = .success(loaded.overridingEndpointFromLaunchArguments())
#else
            settingsResult = .success(loaded)
#endif
        } catch {
            settingsResult = .failure(error)
        }
    }

    var settings: ShellSettings? {
        guard case .success(let value) = settingsResult else { return nil }
        return value
    }

    var settingsFailure: Error? {
        guard case .failure(let error) = settingsResult else { return nil }
        return error
    }

    func bootstrap(
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        guard !bootstrapped else { return }
        bootstrapped = true

        messaging.configure(application: application)

        guard case .success(let settings) = settingsResult else { return }
        do {
            try signature.initialize(
                devKey: settings.attributionDevKey,
                appId: settings.appleAppID
            )
            try signature.handleLaunchOptions(launchOptions)
            try signature.registerSessionReadyListener()
        } catch {
            startupFailure = error
        }
    }
}
