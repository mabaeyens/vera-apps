import SwiftUI

private struct FlatRow: Identifiable {
    let id: UUID
    let node: FileNode
    let depth: Int
}

struct FileTreeView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Binding var selectedURL: URL?

    @State private var selectedID: UUID?
    @State private var fileToDelete: (url: URL, name: String)?
    @State private var expandedFolders: Set<UUID> = []
    @State private var loadedFolderIDs: Set<UUID> = []
    @AppStorage("openFilesExpanded") private var openFilesExpanded: Bool = true
    #if os(macOS)
    @State private var hoveredTabID: UUID?
    #endif

    var body: some View {
        Group {
            if vm.isLoading && vm.roots.isEmpty && vm.standaloneFiles.isEmpty && vm.tabs.isEmpty {
                ProgressView("Loading files…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.roots.isEmpty && vm.standaloneFiles.isEmpty && vm.tabs.isEmpty {
                if vm.loadFailed {
                    ContentUnavailableView {
                        Label("Couldn't Load Files", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Try Again") { Task { await vm.load() } }
                    }
                } else {
                    ContentUnavailableView(
                        "No Markdown Files",
                        systemImage: "doc.text",
                        description: Text("No .md files found in the selected folder.")
                    )
                }
            } else {
                List(selection: $selectedID) {
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
                            ForEach(flattenedRows()) { row in
                                rowView(for: row.node)
                                    .padding(.leading, CGFloat(row.depth) * 20)
                            }
                        }
                    }
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
        .task { await vm.load() }
        // UUID selection → URL (user taps a file)
        .onChange(of: selectedID) { _, id in
            guard let id else { selectedURL = nil; return }
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
        // URL → UUID (programmatic selection e.g. new file created or tab switch)
        .onChange(of: selectedURL) { _, url in
            guard let url else {
                selectedID = nil
                return
            }
            let found = findID(url: url, in: vm.roots) ?? findID(url: url, in: vm.standaloneFiles)
            if found != selectedID {
                selectedID = found
            }
        }
    }

    private func flattenedRows() -> [FlatRow] {
        var result: [FlatRow] = []
        func visit(_ nodes: [FileNode], depth: Int) {
            for node in nodes {
                result.append(FlatRow(id: node.id, node: node, depth: depth))
                if case .folder(let id, _, _, let children) = node,
                   expandedFolders.contains(id) {
                    visit(children, depth: depth + 1)
                }
            }
        }
        visit(vm.roots, depth: 0)
        return result
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
            }
        }
        .contentShape(Rectangle())
        .onHover { hoveredTabID = $0 ? tab.id : nil }
        .onTapGesture { vm.openFileInActiveTab(tab.url) }
        #else
        Button {
            vm.openFileInActiveTab(tab.url)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .frame(width: 6, height: 6)
                Text(tab.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button { vm.closeTab(tab.id) } label: {
                    Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
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
    private func rowView(for node: FileNode) -> some View {
        switch node {
        case .folder(let id, let name, let folderURL, _):
            Button {
                if expandedFolders.contains(id) {
                    expandedFolders.remove(id)
                } else {
                    expandedFolders.insert(id)
                    if !loadedFolderIDs.contains(id) {
                        loadedFolderIDs.insert(id)
                        Task { await vm.loadFolderChildren(id: id, url: folderURL) }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: expandedFolders.contains(id) ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Label(name, systemImage: "folder")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        case .file(let id, let name, let url, let state):
            #if os(macOS)
            MacFileRow(
                name: name,
                url: url,
                downloadState: state,
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
                    Label(name, systemImage: "doc.text")
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
    let isDownloading: Bool
    let isOnline: Bool
    let onDelete: () -> Void
    let onDownload: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            Label(name, systemImage: "doc.text")
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
                    Button { onDelete() } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
#endif
