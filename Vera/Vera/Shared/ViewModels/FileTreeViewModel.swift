import Foundation
import Observation

@Observable
@MainActor
final class FileTreeViewModel {
    var roots: [FileNode] = []
    var selectedURL: URL?
    var isLoading = false
    var needsFolderPicker = false
    var downloadingURLs: Set<URL> = []

    private(set) var rootURL: URL?
    private var refreshTask: Task<Void, Never>?

    init() {
        let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        needsFolderPicker = hasSeen && UserDefaults.standard.data(forKey: "rootFolderBookmark") == nil
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        if rootURL == nil {
            rootURL = restoredBookmark()
        } else {
            _ = rootURL?.startAccessingSecurityScopedResource()
        }
        needsFolderPicker = rootURL == nil
        guard let root = rootURL else { return }

        await Task.yield()
        do {
            roots = try await CloudScanner.scan(root: root)
            repinDownloads()
        } catch {
            roots = []
        }
    }

    // Re-trigger download for previously opened files that iCloud evicted.
    private func repinDownloads() {
        var pinned = pinnedPaths
        let cloudURLs = cloudFileURLs(in: roots)
        var cleaned = false
        for path in pinned {
            let url = URL(fileURLWithPath: path)
            if cloudURLs.contains(url) {
                download(url)
            } else if !FileManager.default.fileExists(atPath: path) {
                pinned.remove(path)
                cleaned = true
            }
        }
        if cleaned { pinnedPaths = pinned }
    }

    private func cloudFileURLs(in nodes: [FileNode]) -> Set<URL> {
        var result = Set<URL>()
        for node in nodes {
            switch node {
            case .file(_, _, let url, .cloud): result.insert(url)
            case .folder(_, _, let children): result.formUnion(cloudFileURLs(in: children))
            default: break
            }
        }
        return result
    }

    func setRoot(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        saveBookmark(url)
        needsFolderPicker = false
        rootURL = url
        roots = []
        Task { await load() }
    }

    func download(_ url: URL) {
        downloadingURLs.insert(url)
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        scheduleRefresh()
    }

    func pinFile(_ url: URL) {
        pinnedPaths.insert(url.path)
    }

    func deleteFile(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
        if selectedURL == url { selectedURL = nil }
        await load()
    }

    @discardableResult
    func createFile(named name: String, in folder: URL) async throws -> URL {
        let filename = name.hasSuffix(".md") ? name : name + ".md"
        let fileURL = folder.appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        await load()
        return fileURL
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await load()
            downloadingURLs = downloadingURLs.filter { cloudFileURLs(in: roots).contains($0) }
        }
    }

    // MARK: - Pinned file persistence

    private var pinnedPaths: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: "pinnedFiles") ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "pinnedFiles")
        }
    }

    // MARK: - Bookmark persistence

    private func restoredBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: "rootFolderBookmark") else { return nil }
        var stale = false
        #if os(macOS)
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        #else
        guard let url = try? URL(
            resolvingBookmarkData: data,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        #endif
        if stale { saveBookmark(url) }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    private func saveBookmark(_ url: URL) {
        #if os(macOS)
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        #else
        guard let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        #endif
        UserDefaults.standard.set(data, forKey: "rootFolderBookmark")
    }
}
