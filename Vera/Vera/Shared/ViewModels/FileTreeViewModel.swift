import Foundation
import Observation

@Observable
@MainActor
final class FileTreeViewModel {
    var roots: [FileNode] = []
    var selectedURL: URL?
    var isLoading = false
    var rootUnavailable = false
    var needsFolderPicker = false

    private var rootURL: URL?
    private var refreshTask: Task<Void, Never>?

    func load() async {
        isLoading = true
        defer { isLoading = false }

        #if os(macOS)
        rootURL = CloudScanner.defaultRoot()
        rootUnavailable = rootURL == nil
        #else
        if rootURL == nil {
            rootURL = restoredBookmark()
        }
        needsFolderPicker = rootURL == nil
        #endif

        guard let root = rootURL else { return }

        do {
            roots = try CloudScanner.scan(root: root)
        } catch {
            roots = []
        }
    }

    func setRoot(_ url: URL) {
        #if os(iOS)
        _ = url.startAccessingSecurityScopedResource()
        saveBookmark(url)
        needsFolderPicker = false
        #endif
        rootURL = url
        Task { await load() }
    }

    func download(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        scheduleRefresh()
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    // MARK: - iOS bookmark persistence

    #if os(iOS)
    private func restoredBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: "rootFolderBookmark") else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return nil }
        if stale { saveBookmark(url) }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    private func saveBookmark(_ url: URL) {
        guard let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: "rootFolderBookmark")
    }
    #endif
}
