import SwiftUI

struct FileTreeView: View {
    @Environment(FileTreeViewModel.self) private var vm
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
                        NodeRow(node: node)
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
        .task { await vm.load() }
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
                selectedURL = url
            } label: {
                HStack {
                    Label(name, systemImage: "doc.text")
                    Spacer()
                    if state == .cloud {
                        Image(systemName: "icloud.and.arrow.down")
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
    @State private var isExpanded = true

    var body: some View {
        switch node {
        case .folder(_, let name, let children):
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    NodeRow(node: child)
                }
            } label: {
                Label(name, systemImage: "folder")
            }
        case .file(_, let name, let url, let state):
            HStack {
                Label(name, systemImage: "doc.text")
                Spacer()
                if state == .cloud {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .tag(url)
        }
    }
}
#endif
