import SwiftUI

struct FileTreeView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Binding var selectedURL: URL?

    @State private var selectedID: UUID?

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
                    OutlineGroup(vm.roots, children: \.children) { node in
                        nodeRow(node)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !connectivity.isOnline { offlineBanner }
        }
        .task { await vm.load() }
        // UUID selection → URL (user taps a file)
        .onChange(of: selectedID) { _, id in
            guard let id else {
                selectedURL = nil
                return
            }
            if let url = findURL(id: id, in: vm.roots) {
                selectedURL = url
            }
            // Folder tapped: do not clear selectedURL
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
        case .file(_, let name, let url, let state):
            HStack {
                Label(name, systemImage: "doc.text")
                Spacer()
                if state == .cloud { cloudBadge(for: url) }
            }
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func cloudBadge(for url: URL) -> some View {
        let icon = connectivity.isOnline ? "icloud.and.arrow.down" : "icloud.slash"
        #if os(macOS)
        Button { if connectivity.isOnline { vm.download(url) } } label: {
            Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
        }
        .buttonStyle(.plain)
        .disabled(!connectivity.isOnline)
        .help(connectivity.isOnline ? "Download from iCloud" : "Not available offline")
        #else
        Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
        #endif
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

    private func findURL(id: UUID, in nodes: [FileNode]) -> URL? {
        for node in nodes {
            switch node {
            case .file(let nid, _, let url, _):
                if nid == id { return url }
            case .folder(_, _, let children):
                if let found = findURL(id: id, in: children) { return found }
            }
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
