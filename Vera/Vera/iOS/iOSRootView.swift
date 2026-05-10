#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct iOSRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedURL: URL?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showAbout = false
    @State private var showNewFile = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some View {
        @Bindable var vm = vm
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileTreeView(selectedURL: $selectedURL)
                .navigationTitle("Vera")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showAbout = true } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showNewFile = true } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .disabled(vm.rootURL == nil)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { vm.needsFolderPicker = true } label: {
                            Image(systemName: "folder")
                        }
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
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showNewFile) {
            NewFileSheet { url in
                selectedURL = url
                if horizontalSizeClass == .compact {
                    columnVisibility = .detailOnly
                }
            }
            .environment(vm)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if UserDefaults.standard.data(forKey: "rootFolderBookmark") == nil {
                vm.needsFolderPicker = true
            }
        }) {
            OnboardingView()
        }
        .onChange(of: selectedURL) { _, url in
            if url != nil, horizontalSizeClass == .compact {
                columnVisibility = .detailOnly
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
