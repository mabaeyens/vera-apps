import Foundation
import Observation

@Observable
@MainActor
final class FileTreeViewModel {
    var roots: [FileNode] = []
    var selectedURL: URL?
    var isLoading = false
    var iCloudUnavailable = false

    private var metadataQuery: NSMetadataQuery?
    private var refreshTask: Task<Void, Never>?

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let root = CloudScanner.iCloudRoot() else {
            iCloudUnavailable = true
            return
        }

        iCloudUnavailable = false
        do {
            roots = try CloudScanner.scan(root: root)
        } catch {
            roots = []
        }

        startMetadataWatcher()
    }

    func download(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        scheduleRefresh()
    }

    // MARK: - Private

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private func startMetadataWatcher() {
        guard metadataQuery == nil else { return }
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: q,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }

        q.start()
        metadataQuery = q
    }
}
