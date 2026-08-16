import Combine
import SwiftUI
import UIKit
import WebKit

/// Витрина. Один персистентный `WKWebView` на весь web-режим: пересоздание
/// теряет cookies, сессию, состояние формы и скролл, поэтому смена адреса идёт
/// через обновление, а не через новое представление.
struct WebSurface: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let url: URL
    private let externalSchemes: Set<String>
    @StateObject private var state = WebSurfaceState()

    init(url: URL, externalSchemes: Set<String>) {
        self.url = url
        self.externalSchemes = Set(externalSchemes.map { $0.lowercased() })
    }

    var body: some View {
        WebSurfaceBridge(
            sourceURL: url,
            externalSchemes: externalSchemes,
            state: state
        )
        .overlay(alignment: .top) {
            VStack(spacing: 10) {
                if state.isLoading {
                    ProgressView(value: state.progress)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                        .accessibilityLabel("Loading webpage")
                        .accessibilityValue(progressAccessibilityValue)
                }

                if let failureMessage = state.failureMessage {
                    WebFailureStrip(
                        message: failureMessage,
                        onRetry: state.retry
                    )
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: state.isLoading)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: state.failureMessage)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var progressAccessibilityValue: String {
        "\(Int((state.progress * 100).rounded())) percent"
    }
}

@MainActor
private final class WebSurfaceState: ObservableObject {
    @Published fileprivate var progress = 0.0
    @Published fileprivate var isLoading = true
    @Published fileprivate var failureMessage: String?

    fileprivate var retryHandler: (() -> Void)?

    fileprivate func beginLoading() {
        failureMessage = nil
        isLoading = true
        progress = 0
    }

    fileprivate func finishLoading() {
        progress = 1
        isLoading = false
        failureMessage = nil
    }

    fileprivate func showFailure(_ message: String) {
        isLoading = false
        failureMessage = message
    }

    fileprivate func retry() {
        retryHandler?()
    }
}

private struct WebFailureStrip: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Retry", action: onRetry)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityHint("Attempts to load the webpage again")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }
}

@MainActor
private struct WebSurfaceBridge: UIViewRepresentable {
    let sourceURL: URL
    let externalSchemes: Set<String>
    let state: WebSurfaceState

    func makeCoordinator() -> Pilot {
        Pilot(state: state, externalSchemes: externalSchemes)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        context.coordinator.attach(to: webView)
        context.coordinator.loadSourceURL(sourceURL, in: webView)
        return webView
    }

    /// Адрес меняется здесь, а не пересозданием представления.
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.externalSchemes = externalSchemes

        guard context.coordinator.sourceURL != sourceURL else { return }
        context.coordinator.loadSourceURL(sourceURL, in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Pilot) {
        coordinator.detach(from: webView)
    }

    @MainActor
    final class Pilot: NSObject, WKNavigationDelegate, WKUIDelegate {
        fileprivate var sourceURL: URL?
        fileprivate var externalSchemes: Set<String>

        private let state: WebSurfaceState
        private weak var webView: WKWebView?
        private var progressObservation: NSKeyValueObservation?
        private var lastAttemptedURL: URL?
        private var redirectRetryAvailable = true

        init(state: WebSurfaceState, externalSchemes: Set<String>) {
            self.state = state
            self.externalSchemes = externalSchemes
        }

        deinit {
            progressObservation?.invalidate()
        }

        fileprivate func attach(to webView: WKWebView) {
            self.webView = webView
            state.retryHandler = { [weak self] in
                self?.retryAfterVisibleFailure()
            }

            progressObservation = webView.observe(
                \.estimatedProgress,
                options: [.initial, .new]
            ) { [weak state] _, change in
                guard let progress = change.newValue else { return }
                Task { @MainActor in
                    state?.progress = min(max(progress, 0), 1)
                }
            }
        }

        fileprivate func detach(from webView: WKWebView) {
            progressObservation?.invalidate()
            progressObservation = nil
            state.retryHandler = nil
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            self.webView = nil
        }

        fileprivate func loadSourceURL(_ url: URL, in webView: WKWebView) {
            sourceURL = url
            lastAttemptedURL = url
            redirectRetryAvailable = true
            state.beginLoading()
            webView.load(URLRequest(url: url))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(navigationPolicy(for: navigationAction))
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let targetURL = navigationAction.request.url else { return nil }

            let scheme = targetURL.scheme?.lowercased()
            if scheme == "http" || scheme == "https" {
                beginExplicitNavigation(to: targetURL)
                webView.load(navigationAction.request)
            } else if scheme != nil {
                // `target=_blank` на неверевой схеме — осознанный диплинк в другое
                // приложение, он уходит системе как есть.
                openExternally(targetURL)
            }

            // nil не даёт создать второе окно: http(s) выше намеренно грузится в
            // тот же самый персистентный webview.
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            state.failureMessage = nil
            state.isLoading = true
        }

        func webView(
            _ webView: WKWebView,
            didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation?
        ) {
            if let redirectedURL = webView.url {
                lastAttemptedURL = redirectedURL
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
            state.failureMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            if let finalURL = webView.url {
                lastAttemptedURL = finalURL
            }
            redirectRetryAvailable = true
            state.finishLoading()
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            handleNavigationFailure(error, in: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            handleNavigationFailure(error, in: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            state.beginLoading()
            if webView.url != nil {
                webView.reload()
            } else if let lastAttemptedURL {
                webView.load(URLRequest(url: lastAttemptedURL))
            }
        }

        private func navigationPolicy(for navigationAction: WKNavigationAction) -> WKNavigationActionPolicy {
            guard let navigationURL = navigationAction.request.url,
                  let scheme = navigationURL.scheme?.lowercased() else {
                return .allow
            }

            switch scheme {
            case "http", "https":
                if navigationAction.targetFrame?.isMainFrame != false {
                    if isExplicitNavigation(navigationAction.navigationType) {
                        beginExplicitNavigation(to: navigationURL)
                    } else {
                        lastAttemptedURL = navigationURL
                    }
                }
                return .allow

            case "about", "blob", "data":
                return .allow

            default:
                // Диплинк webview загрузить не может, поэтому навигация уходит
                // системе, а не теряется. Отмена оставляет текущую страницу на
                // экране: возврат из другого приложения не приводит на ошибку, а
                // неустановленный адресат просто ничего не делает.
                //
                // Безусловно пробрасывается только main frame. Подкадр обязан
                // назвать свою схему в списке разрешённых — иначе скрытый iframe
                // мог бы увести пользователя без единого тапа.
                if navigationAction.targetFrame?.isMainFrame != false
                    || externalSchemes.contains(scheme) {
                    openExternally(navigationURL)
                }
                return .cancel
            }
        }

        private func isExplicitNavigation(_ type: WKNavigationType) -> Bool {
            switch type {
            case .linkActivated, .formSubmitted, .formResubmitted, .reload, .backForward:
                return true
            case .other:
                return false
            @unknown default:
                return false
            }
        }

        private func beginExplicitNavigation(to url: URL) {
            lastAttemptedURL = url
            redirectRetryAvailable = true
        }

        private func openExternally(_ url: URL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }

        private func handleNavigationFailure(_ error: Error, in webView: WKWebView) {
            let nsError = error as NSError
            // Отменённая навигация — не ошибка: так выглядит любой уведённый
            // системе диплинк.
            guard !(nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue) else {
                return
            }

            if nsError.domain == NSURLErrorDomain,
               nsError.code == URLError.httpTooManyRedirects.rawValue {
                retryAfterRedirectLoop(in: webView)
                return
            }

            state.showFailure(message(for: nsError))
        }

        /// Ровно один автоповтор последнего адреса, дальше — баннер.
        private func retryAfterRedirectLoop(in webView: WKWebView) {
            guard redirectRetryAvailable, let lastAttemptedURL else {
                state.showFailure("The page redirected too many times.")
                return
            }

            redirectRetryAvailable = false
            state.beginLoading()
            webView.load(URLRequest(url: lastAttemptedURL))
        }

        private func retryAfterVisibleFailure() {
            guard let webView else { return }

            redirectRetryAvailable = true
            state.beginLoading()

            if let lastAttemptedURL {
                webView.load(URLRequest(url: lastAttemptedURL))
            } else if webView.url != nil {
                webView.reload()
            }
        }

        private func message(for error: NSError) -> String {
            guard error.domain == NSURLErrorDomain else {
                return "The page could not be loaded."
            }

            switch URLError.Code(rawValue: error.code) {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Check your connection and try again."
            case .timedOut:
                return "The request timed out. Please try again."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "The server could not be reached."
            default:
                return "The page could not be loaded."
            }
        }
    }
}
