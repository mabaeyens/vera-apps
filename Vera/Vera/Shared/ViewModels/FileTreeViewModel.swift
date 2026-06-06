import Foundation
import Observation

// MARK: - Error type

enum FileOpenError: LocalizedError, Identifiable {
    case notMarkdown(URL)
    case fileNotFound(URL)
    case accessDenied(URL)

    var id: String { localizedDescription }

    var errorDescription: String? {
        switch self {
        case .notMarkdown(let url):
            return "\"\(url.lastPathComponent)\" is not a Markdown file."
        case .fileNotFound(let url):
            return "\"\(url.lastPathComponent)\" could not be found."
        case .accessDenied(let url):
            return "Cannot access \"\(url.lastPathComponent)\". Try opening the file again from its original location."
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class FileTreeViewModel {
    var roots: [FileNode] = []
    var selectedURL: URL?
    var isLoading = false
    var loadFailed = false
    var needsFolderPicker = false
    var standaloneFiles: [FileNode] = []
    var downloadingURLs: Set<URL> = []
    var fileOpenError: FileOpenError? = nil

    // Tracks URLs for which we hold an open security-scoped access grant,
    // so we can release them when their tab is closed.
    private var accessedURLs: Set<URL> = []

    // MARK: - Tab management

    struct TabEntry: Identifiable {
        let id: UUID
        var url: URL
        var name: String { url.deletingPathExtension().lastPathComponent }

        init(url: URL) {
            self.id = UUID()
            self.url = url
        }
    }

    var tabs: [TabEntry] = []
    var activeTabID: UUID? = nil

    func openFileInActiveTab(_ url: URL) {
        if let existing = tabs.first(where: { $0.url == url }) {
            activeTabID = existing.id
            selectedURL = url
            return
        }
        if tabs.isEmpty {
            let entry = TabEntry(url: url)
            tabs = [entry]
            activeTabID = entry.id
        } else if let idx = tabs.firstIndex(where: { $0.id == activeTabID }) {
            tabs[idx].url = url
        } else {
            let entry = TabEntry(url: url)
            tabs.append(entry)
            activeTabID = entry.id
        }
        selectedURL = url
    }

    func openFileInNewTab(_ url: URL) {
        if let existing = tabs.first(where: { $0.url == url }) {
            activeTabID = existing.id
            selectedURL = url
            return
        }
        let entry = TabEntry(url: url)
        tabs.append(entry)
        activeTabID = entry.id
        selectedURL = url
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let closedURL = tabs[idx].url
        tabs.remove(at: idx)
        if activeTabID == id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs[newIdx].id
            selectedURL = tabs[newIdx].url
        }
        releaseAccess(closedURL)
    }

    // MARK: - Unified file-open coordinator

    /// Single entry point for all file-open gestures: external app, Cmd+O, drag-and-drop, file picker.
    /// Handles validation, security-scoped access, and routing (in-root / standalone / root-change).
    func openFile(_ url: URL) {
        // Start access before stat-ing — required for externally vended URLs.
        let accessStarted = url.startAccessingSecurityScopedResource()

        let resolved = url.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir)

        guard exists else {
            if accessStarted { url.stopAccessingSecurityScopedResource() }
            fileOpenError = .fileNotFound(url)
            return
        }

        if isDir.boolValue {
            // Stop openFile's scope — setRoot starts its own scope and owns it from here.
            if accessStarted { url.stopAccessingSecurityScopedResource() }
            setRoot(url)
            return
        }

        guard ["md", "markdown"].contains(resolved.pathExtension.lowercased()) else {
            if accessStarted { url.stopAccessingSecurityScopedResource() }
            fileOpenError = .notMarkdown(url)
            return
        }

        // Track the access grant so we can release it when the tab closes.
        if accessStarted {
            accessedURLs.insert(resolved)
        }

        if let root = rootURL, resolved.path.hasPrefix(root.path + "/") {
            openFileInNewTab(resolved)
        } else if rootURL == nil {
            pendingExternalURL = resolved
            setRoot(url.deletingLastPathComponent())
        } else {
            addStandaloneAndSelect(resolved)
        }
    }

    func releaseAccess(_ url: URL) {
        guard accessedURLs.contains(url) else { return }
        url.stopAccessingSecurityScopedResource()
        accessedURLs.remove(url)
    }

    private func addStandaloneAndSelect(_ url: URL) {
        let alreadyPresent = standaloneFiles.contains { node in
            if case .file(_, _, let u, _) = node { return u == url }
            return false
        }
        if !alreadyPresent {
            let name = url.deletingPathExtension().lastPathComponent
            standaloneFiles.append(.file(id: UUID(), name: name, url: url, downloadState: .local))
        }
        openFileInNewTab(url)
    }

    func activateTab(_ id: UUID) {
        guard let entry = tabs.first(where: { $0.id == id }) else { return }
        activeTabID = entry.id
        selectedURL = entry.url
    }

    // MARK: - State

    private(set) var rootURL: URL?
    private var refreshTask: Task<Void, Never>?
    private var pendingExternalURL: URL?

    init() {
        let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        needsFolderPicker = hasSeen && UserDefaults.standard.data(forKey: "rootFolderBookmark") == nil
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        if rootURL == nil {
            rootURL = restoredBookmark()
        } else {
            _ = rootURL?.startAccessingSecurityScopedResource()
        }
        needsFolderPicker = rootURL == nil
        guard let root = rootURL else { return }

        do {
            roots = try await withThrowingTaskGroup(of: [FileNode].self) { group in
                group.addTask { try await CloudScanner.scan(root: root) }
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    throw URLError(.timedOut)
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
            repinDownloads()
            if let pending = pendingExternalURL {
                openFileInNewTab(pending)
                pendingExternalURL = nil
            }
        } catch {
            loadFailed = true
            // If the root directory itself is gone, clear the stale bookmark and show picker
            if !FileManager.default.fileExists(atPath: root.path) {
                UserDefaults.standard.removeObject(forKey: "rootFolderBookmark")
                rootURL = nil
                roots = []
                needsFolderPicker = true
            }
            // Otherwise (transient iCloud error): keep existing roots so sidebar isn't blanked
        }
    }

    func openExternalURL(_ url: URL) {
        openFile(url)
    }

    func openStandaloneFile(_ url: URL) {
        openFile(url)
    }

    func resetState() {
        UserDefaults.standard.removeObject(forKey: "rootFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "pinnedFiles")
        refreshTask?.cancel()
        refreshTask = nil
        roots = []
        standaloneFiles = []
        tabs = []
        activeTabID = nil
        rootURL = nil
        downloadingURLs = []
        selectedURL = nil
        isLoading = false
        loadFailed = false
        pendingExternalURL = nil
        needsFolderPicker = true
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

    // MARK: - Lazy folder loading

    func loadFolderChildren(id: UUID, url: URL) async {
        let children = (try? await CloudScanner.scanShallow(at: url)) ?? []
        roots = replacingChildren(in: roots, forID: id, with: children)
    }

    private func replacingChildren(in nodes: [FileNode], forID targetID: UUID, with newChildren: [FileNode]) -> [FileNode] {
        nodes.map { node in
            guard case .folder(let id, let name, let url, let children) = node else { return node }
            if id == targetID {
                return .folder(id: id, name: name, url: url, children: newChildren)
            }
            return .folder(id: id, name: name, url: url, children: replacingChildren(in: children, forID: targetID, with: newChildren))
        }
    }

    // MARK: - In-place tree patching

    private func insertingFile(_ node: FileNode, into nodes: [FileNode], parentURL: URL) -> [FileNode] {
        nodes.map { existing in
            guard case .folder(let id, let name, let url, var children) = existing else { return existing }
            if url == parentURL {
                children.append(node)
                let sort: (FileNode, FileNode) -> Bool = { $0.name.localizedCompare($1.name) == .orderedAscending }
                children.sort(by: sort)
                return .folder(id: id, name: name, url: url, children: children)
            }
            return .folder(id: id, name: name, url: url, children: insertingFile(node, into: children, parentURL: parentURL))
        }
    }

    private func removingFile(url targetURL: URL, from nodes: [FileNode]) -> [FileNode] {
        nodes.compactMap { node in
            switch node {
            case .file(_, _, let url, _):
                return url == targetURL ? nil : node
            case .folder(let id, let name, let url, let children):
                return .folder(id: id, name: name, url: url, children: removingFile(url: targetURL, from: children))
            }
        }
    }

    private func cloudFileURLs(in nodes: [FileNode]) -> Set<URL> {
        var result = Set<URL>()
        for node in nodes {
            switch node {
            case .file(_, _, let url, .cloud): result.insert(url)
            case .folder(_, _, _, let children): result.formUnion(cloudFileURLs(in: children))
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
        releaseAccess(url)
        // Remove from standalone files list
        standaloneFiles.removeAll { node in
            if case .file(_, _, let u, _) = node { return u == url }
            return false
        }
        // Patch the folder tree in-place (avoids a full re-scan)
        roots = removingFile(url: url, from: roots)
        // Handle tabs: close the deleted file's tab or clear selection
        if let tabToClose = tabs.first(where: { $0.url == url }) {
            if tabs.count == 1 {
                tabs = []
                activeTabID = nil
                selectedURL = nil
            } else {
                closeTab(tabToClose.id)
            }
        } else if selectedURL == url {
            selectedURL = nil
        }
    }

    @discardableResult
    func createFile(named name: String, in folder: URL) async throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), !trimmed.contains("..") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let filename = trimmed.hasSuffix(".md") ? trimmed : trimmed + ".md"
        let fileURL = folder.appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        let newNode = FileNode.file(id: UUID(), name: filename.replacingOccurrences(of: ".md", with: ""), url: fileURL, downloadState: .local)
        if folder == rootURL {
            // Insert at root level
            var updated = roots
            updated.append(newNode)
            let sort: (FileNode, FileNode) -> Bool = { $0.name.localizedCompare($1.name) == .orderedAscending }
            updated.sort(by: sort)
            roots = updated
        } else {
            roots = insertingFile(newNode, into: roots, parentURL: folder)
        }
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
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
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
