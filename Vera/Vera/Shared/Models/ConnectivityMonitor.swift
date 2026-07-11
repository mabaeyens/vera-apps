import Network
import Observation

@Observable
@MainActor
final class ConnectivityMonitor {
    var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "vera.connectivity")
    // A class's deinit has implicit nonisolated access to its stored properties (the
    // language treats deinit specially, since no concurrent access can be in flight by
    // then) — no isolation annotation is needed here at all; `nonisolated(unsafe)` was
    // redundant, which is what the compiler warning was pointing out.
    @ObservationIgnored
    private var monitorTask: Task<Void, Never>?

    init() {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        monitor.pathUpdateHandler = { path in
            continuation.yield(path.status == .satisfied)
        }
        monitor.start(queue: queue)
        monitorTask = Task { @MainActor [weak self] in
            for await online in stream {
                self?.isOnline = online
            }
        }
    }

    deinit {
        monitor.cancel()
        monitorTask?.cancel()
    }
}
