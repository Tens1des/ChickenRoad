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

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let updated: State = path.status == .satisfied ? .online : .offline
            self.gate.lock()
            let changed = self.currentState != updated
            self.currentState = updated
            self.gate.unlock()
            // Только на смену состояния. `NWPathMonitor` присылает обновление на
            // любое шевеление пути — смену интерфейса, VPN, дрожание сети, — и
            // каждое такое `online -> online` запускало новый полный обмен.
            // Первый колбэк проходит всегда: состояние стартует с `.checking`.
            guard changed else { return }
            if let onChange { Task { @MainActor in onChange(updated) } }
        }
        pathMonitor.start(queue: notifyQueue)
    }

    /// Перечитать путь прямо сейчас, не дожидаясь колбэка.
    ///
    /// `NWPathMonitor` присылает обновление сам, но не мгновенно и не всегда:
    /// после возврата сети состояние может ещё какое-то время оставаться
    /// `offline`. Для фонового цикла это неважно, а для явного «Retry» —
    /// решающе: пользователь уже включил интернет и ждёт, что кнопка сработает.
    func refreshNow() {
        guard running else { return }
        let updated: State = pathMonitor.currentPath.status == .satisfied ? .online : .offline
        gate.lock()
        currentState = updated
        gate.unlock()
    }

    func end() {
        pathMonitor.cancel()
        gate.lock()
        running = false
        currentState = .checking
        gate.unlock()
    }

    deinit { pathMonitor.cancel() }
}
