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
                List(selection: $selectedID) {
                    ForEach(flattenedRows()) { row in
                        rowView(for: row.node)
                            .padding(.leading, CGFloat(row.depth) * 20)
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

    private func flattenedRows() -> [FlatRow] {
        var result: [FlatRow] = []
        func visit(_ nodes: [FileNode], depth: Int) {
            for node in nodes {
                result.append(FlatRow(id: node.id, node: node, depth: depth))
                if case .folder(let id, _, let children) = node,
                   expandedFolders.contains(id) {
                    visit(children, depth: depth + 1)
                }
            }
        }
        visit(vm.roots, depth: 0)
        return result
    }

    @ViewBuilder
    private func rowView(for node: FileNode) -> some View {
        switch node {
        case .folder(let id, let name, _):
            Button {
                if expandedFolders.contains(id) {
                    expandedFolders.remove(id)
                } else {
                    expandedFolders.insert(id)
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
                Button(role: .destructive) {
                    fileToDelete = (url, name)
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
            .tag(id)
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
            .contextMenu {
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
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .contentShape(Rectangle())
    }
}
#endif
