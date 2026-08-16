import Foundation

/// Узел разрешения на уведомления: спросить или сразу открыть витрину.
@MainActor
final class ConsentCoordinator {
    private weak var context: MeshContext?

    init(context: MeshContext) {
        self.context = context
    }

    /// Единственная дверь в постоянный web-режим.
    func presentPersistentWeb(_ url: URL) async {
        guard let context else { return }

        if let oneShotPushLink = context.oneShotPushLink {
            context.showWeb(oneShotPushLink)
            return
        }

        let shouldPrompt = await context.consentGate.shouldPrompt(
            skippedAt: context.vault.consentSkippedAt
        )
        context.show(shouldPrompt ? .consent(url) : .web(url))
    }

    func accept() {
        guard let context, case .consent(let destination) = context.destination else { return }
        Task { @MainActor [weak self] in
            guard let self, let context = self.context else { return }
            _ = await context.consentGate.requestSystemAuthorization()
            context.showWeb(destination)
        }
    }

    /// «Skip» системный алерт не вызывает: сохраняем дату и идём в витрину.
    func skip() {
        guard let context, case .consent(let destination) = context.destination else { return }
        context.vault.consentSkippedAt = Date()
        context.showWeb(destination)
    }
}
