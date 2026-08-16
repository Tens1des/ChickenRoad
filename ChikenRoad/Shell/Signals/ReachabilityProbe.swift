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
            self.currentState = updated
            self.gate.unlock()
            if let onChange { Task { @MainActor in onChange(updated) } }
        }
        pathMonitor.start(queue: notifyQueue)
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
