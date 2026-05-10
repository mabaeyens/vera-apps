import SwiftUI

struct FileTreeView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Binding var selectedURL: URL?

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
                #if os(macOS)
                List(selection: $selectedURL) {
                    ForEach(vm.roots) { node in
                        NodeRow(node: node, isOnline: connectivity.isOnline)
                    }
                }
                .listStyle(.sidebar)
                #else
                List(vm.roots, children: \.children) { node in
                    iOSNodeRow(node)
                }
                .listStyle(.sidebar)
                #endif
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !connectivity.isOnline {
                offlineBanner
            }
        }
        .task { await vm.load() }
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

    // MARK: - iOS row (button-driven selection)

    #if !os(macOS)
    @ViewBuilder
    private func iOSNodeRow(_ node: FileNode) -> some View {
        switch node {
        case .folder(_, let name, _):
            Label(name, systemImage: "folder")
        case .file(_, let name, let url, let state):
            Button {
                if state == .cloud {
                    if connectivity.isOnline { vm.download(url) }
                } else {
                    selectedURL = url
                }
            } label: {
                HStack {
                    Label(name, systemImage: "doc.text")
                    Spacer()
                    if state == .cloud {
                        Image(systemName: connectivity.isOnline ? "icloud.and.arrow.down" : "icloud.slash")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    #endif
}

// MARK: - macOS recursive row with DisclosureGroup

#if os(macOS)
private struct NodeRow: View {
    let node: FileNode
    let isOnline: Bool
    @State private var isExpanded = true
    @Environment(FileTreeViewModel.self) private var vm

    var body: some View {
        switch node {
        case .folder(_, let name, let children):
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    NodeRow(node: child, isOnline: isOnline)
                }
            } label: {
                Label(name, systemImage: "folder")
            }
        case .file(_, let name, let url, let state):
            HStack {
                Label(name, systemImage: "doc.text")
                Spacer()
                if state == .cloud {
                    Button {
                        if isOnline { vm.download(url) }
                    } label: {
                        Image(systemName: isOnline ? "icloud.and.arrow.down" : "icloud.slash")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isOnline)
                    .help(isOnline ? "Download from iCloud" : "Not available offline")
                }
            }
            .contentShape(Rectangle())
            .tag(url)
        }
    }
}
#endif
