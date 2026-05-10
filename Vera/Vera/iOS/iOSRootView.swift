#if os(iOS)
import SwiftUI

struct iOSRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @State private var selectedURL: URL?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        @Bindable var vm = vm
        NavigationStack(path: $navigationPath) {
            FileTreeView(selectedURL: $selectedURL)
                .navigationTitle("Vera")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: URL.self) { url in
                    DocumentView(url: url)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { vm.needsFolderPicker = true } label: {
                            Image(systemName: "folder")
                        }
                    }
                }
        }
        .onChange(of: selectedURL) { _, newURL in
            if let url = newURL {
                navigationPath.append(url)
                selectedURL = nil
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
    }
}
#endif
