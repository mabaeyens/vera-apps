import SwiftUI

struct FileTreeView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Binding var selectedSource: DocumentSource?

    @State private var selectedID: UUID?
    @State private var fileToDelete: (url: URL, name: String)?
    @State private var expandedFolders: Set<UUID> = []
    @State private var loadedFolderIDs: Set<UUID> = []
    @AppStorage("openFilesExpanded") private var openFilesExpanded: Bool = true
    @State private var savedRepos: [SavedRepo] = RepoListStore.all()
    @State private var repoBrowser = RepoBrowser()
    @State private var expandedRepos: Set<String> = []        // SavedRepo.id
    @State private var expandedRepoFolders: Set<String> = []  // "repoID|nodeID"
    #if os(macOS)
    @State private var hoveredTabID: UUID?
    #endif

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
                        "No Markdown Files",
                        systemImage: "doc.text",
                        description: Text("No .md files found in this folder.")
                    )
                }
            } else {
                List(selection: $selectedID) {
                    if !savedRepos.isEmpty { gitHubSection }
                    iCloudSections
                }
                .listStyle(.sidebar)
            }
        }
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
        .safeAreaInset(edge: .bottom) {
            if !connectivity.isOnline { offlineBanner }
        }
        .task {
            RepoListStore.startSyncing()
            savedRepos = RepoListStore.all()
            await vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: RepoListStore.didChange)) { _ in
            savedRepos = RepoListStore.all()
        }
        .onReceive(NotificationCenter.default.publisher(for: RepoListStore.didChangeExternally)) { _ in
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
        DisclosureGroup(isExpanded: repoBinding(repo)) {
            repoContent(repo)
        } label: {
            Label {
                Text(repo.displayName).lineLimit(1).truncationMode(.middle)
            } icon: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(Theme.accent)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                RepoListStore.remove(repo); repoBrowser.forget(repo)
            } label: { Label("Remove", systemImage: "trash") }
        }
        .contextMenu {
            Button(role: .destructive) {
                RepoListStore.remove(repo); repoBrowser.forget(repo)
            } label: { Label("Remove Repository", systemImage: "trash") }
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
                Text("No Markdown files").font(.caption).foregroundStyle(.secondary)
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
            return AnyView(
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedRepoFolders.contains(key) },
                    set: { isOpen in
                        if isOpen { expandedRepoFolders.insert(key) }
                        else { expandedRepoFolders.remove(key) }
                    }
                )) {
                    ForEach(node.children) { child in
                        repoNodeRow(child, repoID: repoID)
                    }
                } label: {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "folder.fill").foregroundStyle(Theme.accent)
                        Text(node.name)
                    }
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
                        MarkdownFileIcon()
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
            Section(vm.rootURL?.lastPathComponent ?? "") {
                ForEach(vm.roots) { node in
                    nodeRow(node)
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
            return AnyView(
                DisclosureGroup(isExpanded: folderBinding(id: id, url: folderURL)) {
                    ForEach(node.children ?? []) { child in
                        nodeRow(child)
                    }
                } label: {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Theme.accent)
                        Text(name)
                    }
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

    @ViewBuilder
    private func openFileRow(tab: FileTreeViewModel.TabEntry) -> some View {
        let isActive = tab.id == vm.activeTabID
        #if os(macOS)
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
            Text(tab.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if hoveredTabID == tab.id {
                Button { vm.closeTab(tab.id) } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Close \(tab.name)")
            }
        }
        .contentShape(Rectangle())
        .onHover { hoveredTabID = $0 ? tab.id : nil }
        .onTapGesture { vm.activateTab(tab.id) }
        #else
        Button {
            vm.activateTab(tab.id)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .frame(width: 6, height: 6)
                Text(tab.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { vm.closeTab(tab.id) } label: {
                Label("Close", systemImage: "xmark")
            }
        }
        #endif
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
                onDelete: { fileToDelete = (url, name) },
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
                        MarkdownFileIcon()
                            .foregroundStyle(isActive ? Theme.accent : .secondary)
                    }
                    Spacer()
                    if vm.downloadingURLs.contains(url) {
                        ProgressView().controlSize(.small)
                    } else if state == .cloud {
                        let icon = connectivity.isOnline ? "icloud.and.arrow.down" : "icloud.slash"
                        Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
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
    let onDelete: () -> Void
    let onDownload: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            Label {
                Text(name).fontWeight(isActive ? .medium : .regular)
            } icon: {
                MarkdownFileIcon()
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
                }
                if isHovered {
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                    .accessibilityLabel("Delete \(name)")
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
#endif
