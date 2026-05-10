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
                emptyStateView
            } else {
                #if os(macOS)
                List(vm.roots, children: \.children, selection: $selectedURL) { node in
                    nodeRow(node)
                }
                .listStyle(.sidebar)
                #else
                List(vm.roots, children: \.children) { node in
                    nodeRow(node)
                }
                .listStyle(.sidebar)
                #endif
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Row

    @ViewBuilder
    private func nodeRow(_ node: FileNode) -> some View {
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
            #if os(macOS)
            .tag(url)
            #endif
        }
    }

    // MARK: - Empty states

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Markdown Files",
            systemImage: "doc.text",
            description: Text("No .md files found in the selected folder.")
        )
    }

}
