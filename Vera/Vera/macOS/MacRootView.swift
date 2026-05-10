#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct MacRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedURL: URL?

    var body: some View {
        @Bindable var vm = vm
        NavigationSplitView {
            FileTreeView(selectedURL: $selectedURL)
                .navigationTitle("Vera")
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button { vm.needsFolderPicker = true } label: {
                            Image(systemName: "folder")
                        }
                        .help("Choose folder…")
                    }
                    ToolbarItem(placement: .automatic) {
                        Button { Task { await vm.load() } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh")
                    }
                }
        } detail: {
            if let url = selectedURL {
                DocumentView(url: url)
                    .id(url)
            } else {
                ContentUnavailableView("Select a file", systemImage: "doc.text")
            }
        }
        .fileImporter(
            isPresented: $vm.needsFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                vm.setRoot(url)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.load() } }
        }
    }
}
#endif
