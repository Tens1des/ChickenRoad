import Foundation
import Network

/// Связность как сигнал, приходящий извне.
///
/// До первого колбэка состояние `checking`, а не `offline`: показать «нет
/// интернета» раньше, чем система ответила, значит соврать на холодном старте.
final class ReachabilityProbe: @unchecked Sendable {
    enum State: Equatable, Sendable {
        case checking
        case online
        case offline
    }

    private let pathMonitor: NWPathMonitor
    private let notifyQueue: DispatchQueue
    private let gate = NSLock()
    private var currentState: State = .checking
    private var running = false

    init() {
        pathMonitor = NWPathMonitor()
        notifyQueue = DispatchQueue(label: "henpath.shell.reachability")
    }

    var state: State {
        gate.lock()
        defer { gate.unlock() }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ShellForceOffline") {
            return Self.debugForcedOnlineMarkerPresent ? .online : .offline
        }
#endif
        return currentState
    }

    func begin(onChange: (@MainActor @Sendable (State) -> Void)? = nil) {
        gate.lock()
        guard !running else {
            let known = currentState
            gate.unlock()
            if let onChange { Task { @MainActor in onChange(known) } }
            return
        }
        running = true
        gate.unlock()

#if DEBUG
        // Приёмка офлайн-ветки без отключения сети Mac/VPN:
        //
        //     -ShellForceOffline
        //
        // Пока нет маркера `henpath-online.flag` в temporaryDirectory —
        // считаем сеть мёртвой. Создание файла + Retry имитирует
        // «включили интернет и нажали Повторить».
        if ProcessInfo.processInfo.arguments.contains("-ShellForceOffline") {
            let forced: State = Self.debugForcedOnlineMarkerPresent ? .online : .offline
            gate.lock()
            currentState = forced
            gate.unlock()
            if let onChange { Task { @MainActor in onChange(forced) } }
            return
        }
#endif

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let updated: State = path.status == .satisfied ? .online : .offline
            self.gate.lock()
            self.currentState = updated
            self.gate.unlock()
            if let onChange { Task { @MainActor in onChange(updated) } }
        }
        pathMonitor.start(queue: notifyQueue)
    }

#if DEBUG
    private static var debugForcedOnlineMarkerPresent: Bool {
        FileManager.default.fileExists(atPath: AcceptanceMarkers.online.path)
    }
#endif

    func end() {
        pathMonitor.cancel()
        gate.lock()
        running = false
        currentState = .checking
        gate.unlock()
    }

    deinit { pathMonitor.cancel() }
}

#if DEBUG
/// Маркеры приёмки в Caches контейнера — видны и приложению, и хосту.
enum AcceptanceMarkers {
    private static var caches: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    static var online: URL { caches.appendingPathComponent("henpath-online.flag") }
    static var retry: URL { caches.appendingPathComponent("henpath-retry.flag") }
}
#endif
