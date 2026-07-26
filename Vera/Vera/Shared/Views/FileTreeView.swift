import SwiftUI
import Combine

struct FileTreeView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Binding var selectedSource: DocumentSource?

    @State private var selectedID: UUID?
    @State private var fileToDelete: (url: URL, name: String)?
    @State private var expandedFolders: Set<UUID> = []
    @State private var loadedFolderIDs: Set<UUID> = []
    @State private var didInitialLoad = false
    @AppStorage(Defaults.Key.openFilesExpanded) private var openFilesExpanded: Bool = true
    @AppStorage(Defaults.Key.iCloudFolderExpanded) private var iCloudFolderExpanded: Bool = true
    @State private var savedRepos: [SavedRepo] = RepoListStore.all()
    @State private var repoBrowser = RepoBrowser()
    @State private var expandedRepos: Set<String> = []        // SavedRepo.id
    @State private var expandedRepoFolders: Set<String> = []  // "repoID|nodeID"
    /// Set when closing a GitHub file that has uncommitted changes, so the user gets a
    /// chance to keep them. Local files autosave and close without a prompt.
    @State private var tabPendingClose: FileTreeViewModel.TabEntry?

    /// id of the source shown in the active tab — used to highlight the active row.
    private var activeSourceID: String? {
        vm.tabs.first(where: { $0.id == vm.activeTabID })?.source.id
    }

    /// No iCloud folder, standalone files, or open tabs.
    private var iCloudEmpty: Bool {
        vm.roots.isEmpty && vm.standaloneFiles.isEmpty && vm.tabs.isEmpty
    }

    var body: some View {
        Group {
            if vm.isLoading && iCloudEmpty && savedRepos.isEmpty {
                ProgressView("Loading files…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if iCloudEmpty && savedRepos.isEmpty {
                if vm.loadFailed {
                    ContentUnavailableView {
                        Label("Couldn't Load Files", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Try Again") { Task { await vm.load() } }
                    }
                } else if vm.rootURL == nil {
                    ContentUnavailableView {
                        Label("No Folder Open", systemImage: "folder")
                    } description: {
                        Text("Open a folder to browse and edit its Markdown files.")
                    } actions: {
                        Button("Open Folder…") {
                            NotificationCenter.default.post(name: .veraOpenPicker, object: nil)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Open from GitHub…") {
                            NotificationCenter.default.post(name: .veraOpenGitHub, object: nil)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.text",
                        description: Text("No Markdown, text, JSON, or YAML files found in this folder.")
                    )
                }
            } else if vm.isSearchActive {
                // Results stand in for the tree while a query is active, so there's one
                // sidebar rather than a tree plus a separate results panel.
                SearchResultsView(
                    hits: vm.searchHits,
                    isSearching: vm.isSearching,
                    truncated: vm.searchTruncated,
                    skips: vm.searchSkips,
                    query: vm.searchQuery,
                    onOpen: { hit in
                        vm.openFileInNewTab(hit.url)
                        if hit.lineNumber > 0 {
                            vm.editor(for: .file(hit.url))?.pendingScrollToLine = hit.lineNumber
                        }
                    }
                )
            } else {
                List(selection: $selectedID) {
                    if !savedRepos.isEmpty { gitHubSection }
                    iCloudSections
                }
                .listStyle(.sidebar)
                // Rows used to ghost through the title/toolbar row as they scrolled under
                // it — a half-faded filename sitting at the same weight as the toolbar
                // icons above it. A hard edge cuts them off cleanly instead.
                .veraHardTopEdge()
                #if os(iOS)
                .refreshable { await refreshAll() }
                #endif
            }
        }
        .searchable(
            text: Binding(get: { vm.searchQuery }, set: { vm.searchQuery = $0 }),
            placement: .sidebar,
            prompt: "Search this folder"
        )
        .onChange(of: vm.searchQuery) { _, _ in vm.runSearch() }
        .confirmationDialog(
            "Delete \"\(fileToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let url = fileToDelete?.url {
                    Task { try? await vm.deleteFile(at: url) }
                }
                fileToDelete = nil
            }
            Button("Cancel", role: .cancel) { fileToDelete = nil }
        } message: {
            Text("This file will be permanently deleted.")
        }
        .confirmationDialog(
            "Close \"\(tabPendingClose?.name ?? "")\" without committing?",
            isPresented: Binding(get: { tabPendingClose != nil }, set: { if !$0 { tabPendingClose = nil } }),
            titleVisibility: .visible
        ) {
            Button("Close Without Committing", role: .destructive) {
                if let tab = tabPendingClose { vm.closeTab(tab.id) }
                tabPendingClose = nil
            }
            Button("Cancel", role: .cancel) { tabPendingClose = nil }
        } message: {
            Text("This file has changes that haven't been committed to GitHub. They'll be lost.")
        }
        .safeAreaInset(edge: .bottom) {
            if !connectivity.isOnline { offlineBanner }
        }
        .task {
            RepoListStore.startSyncing()
            savedRepos = RepoListStore.all()
            // On iPhone this view sits at the root of a NavigationStack, and SwiftUI
            // re-fires .task on it every time a pushed file is popped back to the
            // sidebar — guard so that doesn't re-run a full top-level rescan on every
            // "open file, go back." (Legitimate refreshes still happen via
            // FileTreeViewModel.scheduleRefresh/scenePhase, which call load() directly.)
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await vm.load()
        }
        // NSUbiquitousKeyValueStore.didChangeExternallyNotification (and, to be safe,
        // its same-process counterpart) can be posted off the main thread — .onReceive
        // doesn't hop threads on its own, and writing to @State off-main is exactly what
        // triggered "Publishing changes from background threads is not allowed."
        .onReceive(NotificationCenter.default.publisher(for: RepoListStore.didChange).receive(on: DispatchQueue.main)) { _ in
            savedRepos = RepoListStore.all()
        }
        .onReceive(NotificationCenter.default.publisher(for: RepoListStore.didChangeExternally).receive(on: DispatchQueue.main)) { _ in
            savedRepos = RepoListStore.all()
        }
        // macOS List selection → open the iCloud file. (The editor is driven by the
        // active tab / selectedSource; deselection here must NOT clear it, otherwise
        // opening a GitHub file — which sets selectedID to nil — would close itself.)
        .onChange(of: selectedID) { _, id in
            guard let id else { return }
            // Check folder tree first
            if let node = findNode(id: id, in: vm.roots),
               case .file(_, _, let url, let state) = node {
                if state == .cloud { vm.download(url) }
                vm.pinFile(url)
                vm.openFileInNewTab(url)
                return
            }
            // Check standalone files
            if let node = vm.standaloneFiles.first(where: { $0.id == id }),
               case .file(_, _, let url, _) = node {
                vm.openFileInNewTab(url)
            }
        }
        // Active source → highlight the matching iCloud row (file sources only).
        .onChange(of: selectedSource) { _, source in
            if case .file(let url)? = source {
                let found = findID(url: url, in: vm.roots) ?? findID(url: url, in: vm.standaloneFiles)
                if found != selectedID { selectedID = found }
            } else if selectedID != nil {
                selectedID = nil
            }
        }
    }

    /// The file currently shown in the active tab — highlighted in the tree so the
    /// sidebar and the editor stay visually connected.
    private var activeFileURL: URL? {
        if case .file(let url)? = vm.tabs.first(where: { $0.id == vm.activeTabID })?.source {
            return url
        }
        return nil
    }

    /// Synced GitHub repos — a browsable tree alongside the iCloud folders. Expanding a
    /// repo loads its Markdown tree (one API call); tapping a file opens it as a tab.
    @ViewBuilder private var gitHubSection: some View {
        Section("GitHub") {
            ForEach(savedRepos) { repo in
                repoNode(repo)
            }
            Button {
                NotificationCenter.default.post(name: .veraOpenGitHub, object: nil)
            } label: {
                Label("Add Repository…", systemImage: "plus")
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func repoNode(_ repo: SavedRepo) -> some View {
        let binding = repoBinding(repo)
        return DisclosureGroup(isExpanded: binding) {
            repoContent(repo)
        } label: {
            Label {
                Text(repo.displayName).lineLimit(1).truncationMode(.middle)
            } icon: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(Theme.accent)
            }
            .contentShape(Rectangle())
            #if os(iOS)
            // DisclosureGroup only toggles on the chevron by default on iOS — this makes
            // tapping anywhere on the row expand it too. macOS's List/DisclosureGroup
            // click handling is AppKit-backed (NSOutlineView); a competing SwiftUI
            // .onTapGesture there breaks the native chevron-click expand entirely rather
            // than adding a second way to trigger it, so this stays iOS-only.
            .onTapGesture { binding.wrappedValue.toggle() }
            #endif
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                RepoListStore.remove(repo); repoBrowser.forget(repo)
            } label: { Label("Disconnect", systemImage: "xmark.circle") }
        }
        .contextMenu {
            Button(role: .destructive) {
                RepoListStore.remove(repo); repoBrowser.forget(repo)
            } label: {
                // Local-only: this forgets the connection in Vera, nothing changes on GitHub.
                Label("Disconnect Repository", systemImage: "xmark.circle")
            }
        }
    }

    /// Expanding a repo loads its tree; with no token on this device, it instead opens
    /// the connect sheet pre-filled so the user can add the token once.
    private func repoBinding(_ repo: SavedRepo) -> Binding<Bool> {
        Binding(
            get: { expandedRepos.contains(repo.id) },
            set: { isOpen in
                if isOpen {
                    guard CredentialStore.hasToken else {
                        NotificationCenter.default.post(name: .veraOpenGitHub, object: repo)
                        return
                    }
                    expandedRepos.insert(repo.id)
                    Task { await repoBrowser.loadIfNeeded(repo) }
                } else {
                    expandedRepos.remove(repo.id)
                }
            }
        )
    }

    @ViewBuilder private func repoContent(_ repo: SavedRepo) -> some View {
        switch repoBrowser.state(for: repo) {
        case .idle, .loading:
            HStack(spacing: Theme.Space.s) {
                ProgressView().controlSize(.small)
                Text("Loading…").font(.caption).foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        case .loaded(let nodes):
            if nodes.isEmpty {
                Text("No documents").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(nodes) { node in
                    repoNodeRow(node, repoID: repo.id)
                }
            }
        }
    }

    /// Recursive GitHub tree row (AnyView for the same reason as `nodeRow`).
    private func repoNodeRow(_ node: RepoTreeNode, repoID: String) -> AnyView {
        if node.isFolder {
            let key = repoID + "|" + node.id
            let binding = Binding(
                get: { expandedRepoFolders.contains(key) },
                set: { isOpen in
                    if isOpen { expandedRepoFolders.insert(key) }
                    else { expandedRepoFolders.remove(key) }
                }
            )
            return AnyView(
                DisclosureGroup(isExpanded: binding) {
                    ForEach(node.children) { child in
                        repoNodeRow(child, repoID: repoID)
                    }
                } label: {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "folder.fill").foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                        Text(node.name)
                    }
                    .contentShape(Rectangle())
                    #if os(iOS)
                    .onTapGesture { binding.wrappedValue.toggle() }
                    #endif
                }
            )
        } else if let ref = node.ref {
            let isActive = activeSourceID == DocumentSource.gitHub(ref).id
            return AnyView(
                Button {
                    vm.openInNewTab(.gitHub(ref))
                } label: {
                    Label {
                        Text(node.name).fontWeight(isActive ? .medium : .regular)
                            .lineLimit(1).truncationMode(.middle)
                    } icon: {
                        DocumentFileIcon(name: node.name)
                            .foregroundStyle(isActive ? Theme.accent : .secondary)
                    }
                }
                .buttonStyle(.plain)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    /// The iCloud side: open tabs + the folder tree, or an inline "open a folder" prompt
    /// when no folder is open but the list is showing because of GitHub repos.
    @ViewBuilder private var iCloudSections: some View {
        if !vm.tabs.isEmpty {
            Section(isExpanded: $openFilesExpanded) {
                ForEach(vm.tabs) { tab in
                    openFileRow(tab: tab)
                }
            } header: {
                Text("Open Files")
            }
        }
        if !vm.roots.isEmpty {
            // A DisclosureGroup row (leading chevron) so the local folder collapses
            // exactly like a GitHub repo node, not a trailing-chevron section header.
            Section {
                DisclosureGroup(isExpanded: $iCloudFolderExpanded) {
                    ForEach(vm.roots) { node in
                        nodeRow(node)
                    }
                } label: {
                    Label {
                        Text(vm.rootURL?.lastPathComponent ?? "")
                            .lineLimit(1).truncationMode(.middle)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    .contentShape(Rectangle())
                    #if os(iOS)
                    .onTapGesture { iCloudFolderExpanded.toggle() }
                    #endif
                }
            }
        } else if vm.rootURL == nil {
            Section("iCloud") {
                Button {
                    NotificationCenter.default.post(name: .veraOpenPicker, object: nil)
                } label: {
                    Label("Open Folder…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Recursive sidebar row — folders are native `DisclosureGroup`s (so expansion
    /// renders correctly in both the iPhone NavigationStack and the iPad
    /// NavigationSplitView sidebar); children load lazily on first expand.
    /// Returns `AnyView` because a recursive `some View` function can't infer its
    /// own opaque type.
    private func nodeRow(_ node: FileNode) -> AnyView {
        switch node {
        case .folder(let id, let name, let folderURL, _):
            let binding = folderBinding(id: id, url: folderURL)
            return AnyView(
                DisclosureGroup(isExpanded: binding) {
                    ForEach(node.children ?? []) { child in
                        nodeRow(child)
                    }
                } label: {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                        Text(name)
                    }
                    .contentShape(Rectangle())
                    #if os(iOS)
                    .onTapGesture { binding.wrappedValue.toggle() }
                    #endif
                }
            )
        case .file:
            return AnyView(fileRow(node))
        }
    }

    /// Controlled expansion: toggling triggers the existing lazy child load.
    private func folderBinding(id: UUID, url: URL) -> Binding<Bool> {
        Binding(
            get: { expandedFolders.contains(id) },
            set: { isOpen in
                if isOpen {
                    expandedFolders.insert(id)
                    if !loadedFolderIDs.contains(id) {
                        loadedFolderIDs.insert(id)
                        Task { await vm.loadFolderChildren(id: id, url: url) }
                    }
                } else {
                    expandedFolders.remove(id)
                }
            }
        )
    }

    /// One implementation for every platform. The sidebar is now the *only* place open
    /// documents are listed (the tab bar is gone), so the affordances have to be the same
    /// everywhere: tap to activate, an always-visible close control, and a context menu.
    /// The close button used to be macOS hover-only, which DESIGN.md explicitly forbids.
    @ViewBuilder
    private func openFileRow(tab: FileTreeViewModel.TabEntry) -> some View {
        let isActive = tab.id == vm.activeTabID
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(tab.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            dirtyIndicator(for: tab.editor)
            Button { requestClose(tab) } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    #if os(iOS)
                    .frame(width: 44, height: 44)
                    #else
                    .frame(width: 20, height: 20)
                    #endif
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(tab.name)")
        }
        .contentShape(Rectangle())
        .onTapGesture { vm.activateTab(tab.id) }
        .contextMenu {
            Button("Close") { requestClose(tab) }
            Button("Close Others") { vm.closeOtherTabs(besides: tab.id) }
            #if os(macOS)
            if case .file(let url) = tab.source {
                Divider()
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            #endif
        }
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { requestClose(tab) } label: {
                Label("Close", systemImage: "xmark")
            }
        }
        #endif
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// Local files autosave on a 500 ms debounce, so their indicator reflects the in-flight
    /// write and normally just blinks — that's honest about how the file actually behaves.
    /// GitHub files don't autosave, so `.uncommitted` persists until committed.
    @ViewBuilder
    private func dirtyIndicator(for editor: EditorViewModel) -> some View {
        switch editor.saveState {
        case .saved:
            EmptyView()
        case .saving:
            Circle()
                .fill(Color.secondary)
                .frame(width: 5, height: 5)
                .accessibilityLabel("Saving")
        case .uncommitted, .committing:
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .accessibilityLabel("Uncommitted changes")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityLabel("Couldn't save")
        }
    }

    /// Local files just flush and close — prompting would be wrong for an autosaving
    /// editor. GitHub files have no autosave, so uncommitted work really can be lost.
    private func requestClose(_ tab: FileTreeViewModel.TabEntry) {
        if tab.source.isGitHub, tab.editor.isUncommitted {
            tabPendingClose = tab
        } else {
            vm.closeTab(tab.id)
        }
    }

    @ViewBuilder
    private func fileRow(_ node: FileNode) -> some View {
        if case .file(let id, let name, let url, let state) = node {
            let isActive = url == activeFileURL
            #if os(macOS)
            MacFileRow(
                name: name,
                url: url,
                downloadState: state,
                isActive: isActive,
                isDownloading: vm.downloadingURLs.contains(url),
                isOnline: connectivity.isOnline,
                onDownload: { vm.download(url) }
            )
            .contextMenu {
                Button { vm.openFileInNewTab(url) } label: {
                    Label("Open in New Tab", systemImage: "plus.rectangle.on.rectangle")
                }
                Divider()
                Button(role: .destructive) {
                    fileToDelete = (url, name)
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
            .tag(id)
            #else
            // Button wrapper is required: List(selection:) doesn't fire onChange inside
            // NavigationStack on iPhone — only NavigationSplitView enables that path.
            Button {
                if state == .cloud { vm.download(url) }
                vm.pinFile(url)
                vm.openFileInNewTab(url)
            } label: {
                HStack {
                    Label {
                        Text(name).fontWeight(isActive ? .medium : .regular)
                    } icon: {
                        DocumentFileIcon(name: name)
                            .foregroundStyle(isActive ? Theme.accent : .secondary)
                    }
                    Spacer()
                    if vm.downloadingURLs.contains(url) {
                        ProgressView().controlSize(.small)
                    } else if state == .cloud {
                        let icon = connectivity.isOnline ? "icloud.and.arrow.down" : "icloud.slash"
                        Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
                            .accessibilityLabel(connectivity.isOnline ? "In iCloud, not downloaded" : "In iCloud, offline")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    fileToDelete = (url, name)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button { vm.openFileInNewTab(url) } label: {
                    Label("Open in New Tab", systemImage: "plus.rectangle.on.rectangle")
                }
                Divider()
                Button(role: .destructive) {
                    fileToDelete = (url, name)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .accessibilityAddTraits(isActive ? .isSelected : [])
            .tag(id)
            #endif
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
            Text("Offline — changes sync on reconnect")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func findNode(id: UUID, in nodes: [FileNode]) -> FileNode? {
        for node in nodes {
            if node.id == id { return node }
            if case .folder(_, _, _, let children) = node,
               let found = findNode(id: id, in: children) { return found }
        }
        return nil
    }

    private func findID(url: URL, in nodes: [FileNode]) -> UUID? {
        for node in nodes {
            switch node {
            case .file(let id, _, let nodeURL, _):
                if nodeURL == url { return id }
            case .folder(_, _, _, let children):
                if let found = findID(url: url, in: children) { return found }
            }
        }
        return nil
    }

    #if os(iOS)
    /// Pull-to-refresh: rescans the local/iCloud tree and forces every connected GitHub
    /// repo to refetch, bypassing `RepoBrowser`'s session-long cache — otherwise commits
    /// made elsewhere (another device, the web) never show up until the app relaunches.
    private func refreshAll() async {
        await vm.load()
        await withTaskGroup(of: Void.self) { group in
            for repo in savedRepos {
                group.addTask { await repoBrowser.reload(repo) }
            }
        }
    }
    #endif
}

// MARK: - macOS file row

#if os(macOS)
private struct MacFileRow: View {
    let name: String
    let url: URL
    let downloadState: DownloadState
    let isActive: Bool
    let isDownloading: Bool
    let isOnline: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack {
            Label {
                Text(name).fontWeight(isActive ? .medium : .regular)
            } icon: {
                DocumentFileIcon(name: name)
                    .foregroundStyle(isActive ? Theme.accent : .secondary)
            }
            Spacer()
            if isDownloading {
                ProgressView().controlSize(.small)
            } else {
                if downloadState == .cloud {
                    Button { if isOnline { onDownload() } } label: {
                        Image(systemName: isOnline ? "icloud.and.arrow.down" : "icloud.slash")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isOnline)
                    .help(isOnline ? "Download from iCloud" : "Not available offline")
                    .accessibilityLabel(isOnline ? "Download from iCloud" : "In iCloud, offline")
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
#endif
