import Network
import Observation

@Observable
@MainActor
final class ConnectivityMonitor {
    var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "vera.connectivity")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
