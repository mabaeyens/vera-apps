import SwiftUI

struct FileTreeView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Binding var selectedURL: URL?

    @State private var selectedID: UUID?
    @State private var fileToDelete: (url: URL, name: String)?

    // Binding that accepts only file UUIDs — folders never reach selectedID,
    // so NavigationSplitView never pushes the detail pane on folder tap.
    private var fileOnlySelection: Binding<UUID?> {
        Binding(
            get: { selectedID },
            set: { newID in
                guard let newID else { selectedID = nil; return }
                if let node = findNode(id: newID, in: vm.roots), case .file = node {
                    selectedID = newID
                }
            }
        )
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.roots.isEmpty {
                ProgressView("Loading files…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.roots.isEmpty {
                ContentUnavailableView(
                    "No Markdown Files",
                    systemImage: "doc.text",
                    description: Text("No .md files found in the selected folder.")
                )
            } else {
                List(vm.roots, id: \.id, children: \.children, selection: fileOnlySelection) { node in
                    nodeRow(node)
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
            if let node = findNode(id: id, in: vm.roots),
               case .file(_, _, let url, let state) = node {
                if state == .cloud { vm.download(url) }
                vm.pinFile(url)
                selectedURL = url
            }
        }
        // URL → UUID (programmatic selection e.g. new file created)
        .onChange(of: selectedURL) { _, url in
            guard let url else {
                selectedID = nil
                return
            }
            let found = findID(url: url, in: vm.roots)
            if found != selectedID {
                selectedID = found
            }
        }
    }

    @ViewBuilder
    private func nodeRow(_ node: FileNode) -> some View {
        switch node {
        case .folder(_, let name, _):
            Label(name, systemImage: "folder")
                .selectionDisabled()
        case .file(_, let name, let url, let state):
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
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    fileToDelete = (url, name)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    fileToDelete = (url, name)
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
            #else
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
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    fileToDelete = (url, name)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
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
            if case .folder(_, _, let children) = node,
               let found = findNode(id: id, in: children) { return found }
        }
        return nil
    }

    private func findID(url: URL, in nodes: [FileNode]) -> UUID? {
        for node in nodes {
            switch node {
            case .file(let id, _, let nodeURL, _):
                if nodeURL == url { return id }
            case .folder(_, _, let children):
                if let found = findID(url: url, in: children) { return found }
            }
        }
        return nil
    }
}

// MARK: - macOS file row with self-contained hover state

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
            } else if downloadState == .cloud {
                Button { if isOnline { onDownload() } } label: {
                    Image(systemName: isOnline ? "icloud.and.arrow.down" : "icloud.slash")
                        .foregroundStyle(.secondary).font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!isOnline)
                .help(isOnline ? "Download from iCloud" : "Not available offline")
            } else {
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(isHovered ? .primary : .tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
#endif
