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
    var selectedSource: DocumentSource?
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
        var source: DocumentSource
        var name: String { source.displayName }

        init(source: DocumentSource) {
            self.id = UUID()
            self.source = source
        }
    }

    var tabs: [TabEntry] = []
    var activeTabID: UUID? = nil

    func openInActiveTab(_ source: DocumentSource) {
        if let existing = tabs.first(where: { $0.source == source }) {
            activeTabID = existing.id
            selectedSource = source
            return
        }
        if tabs.isEmpty {
            let entry = TabEntry(source: source)
            tabs = [entry]
            activeTabID = entry.id
        } else if let idx = tabs.firstIndex(where: { $0.id == activeTabID }) {
            tabs[idx].source = source
        } else {
            let entry = TabEntry(source: source)
            tabs.append(entry)
            activeTabID = entry.id
        }
        selectedSource = source
    }

    func openInNewTab(_ source: DocumentSource) {
        if let existing = tabs.first(where: { $0.source == source }) {
            activeTabID = existing.id
            selectedSource = source
            return
        }
        let entry = TabEntry(source: source)
        tabs.append(entry)
        activeTabID = entry.id
        selectedSource = source
    }

    // URL convenience wrappers — keep every existing iCloud call site unchanged.
    func openFileInActiveTab(_ url: URL) { openInActiveTab(.file(url)) }
    func openFileInNewTab(_ url: URL) { openInNewTab(.file(url)) }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let closed = tabs[idx].source
        tabs.remove(at: idx)
        if activeTabID == id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs[newIdx].id
            selectedSource = tabs[newIdx].source
        }
        if case .file(let url) = closed { releaseAccess(url) }
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
        selectedSource = entry.source
    }

    // MARK: - State

    private(set) var rootURL: URL?
    private var refreshTask: Task<Void, Never>?
    // Coalesces concurrent load() callers — at launch both FileTreeView's
    // .task and MacRootView's scenePhase==.active fire load() at once.
    private var loadTask: Task<Void, Never>?
    private var pendingExternalURL: URL?

    init() {
        let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        needsFolderPicker = hasSeen && BookmarkStore.load() == nil
    }

    func load() async {
        // Coalesce concurrent callers so launch doesn't run two parallel scans
        // of the same iCloud directory (which can contend and spuriously fail).
        if let existing = loadTask {
            await existing.value
            return
        }
        let task = Task { await performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
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

        // On a cold launch the iCloud container may not be materialised yet, so
        // the first scan can throw transiently. Retry a few times with a short
        // backoff before surfacing a hard error to the user.
        for attempt in 0..<3 {
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
                loadFailed = false
                repinDownloads()
                if let pending = pendingExternalURL {
                    openFileInNewTab(pending)
                    pendingExternalURL = nil
                }
                return
            } catch {
                // If the root directory itself is gone, clear the stale bookmark
                // and show the picker — no point retrying.
                if !FileManager.default.fileExists(atPath: root.path) {
                    BookmarkStore.remove()
                    rootURL = nil
                    roots = []
                    needsFolderPicker = true
                    return
                }
                // Transient (e.g. iCloud not ready): back off and retry.
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
        }
        // Retries exhausted and the folder still exists — surface the error but
        // keep any existing roots so the sidebar isn't blanked.
        loadFailed = true
    }

    func openExternalURL(_ url: URL) {
        openFile(url)
    }

    func openStandaloneFile(_ url: URL) {
        openFile(url)
    }

    func resetState() {
        BookmarkStore.remove()
        UserDefaults.standard.removeObject(forKey: "pinnedFiles")
        refreshTask?.cancel()
        refreshTask = nil
        roots = []
        standaloneFiles = []
        tabs = []
        activeTabID = nil
        rootURL = nil
        downloadingURLs = []
        selectedSource = nil
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
        if let tabToClose = tabs.first(where: { $0.source == .file(url) }) {
            if tabs.count == 1 {
                tabs = []
                activeTabID = nil
                selectedSource = nil
            } else {
                closeTab(tabToClose.id)
            }
        } else if selectedSource == .file(url) {
            selectedSource = nil
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
        guard let data = BookmarkStore.load() else { return nil }
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
        BookmarkStore.save(data)
    }
}
