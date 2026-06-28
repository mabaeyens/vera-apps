import Network
import Observation

@Observable
@MainActor
final class ConnectivityMonitor {
    var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "vera.connectivity")
    nonisolated(unsafe) private var monitorTask: Task<Void, Never>?

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
