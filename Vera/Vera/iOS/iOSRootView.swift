#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct iOSRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @State private var selectedURL: URL?
    @State private var navigationPath = NavigationPath()
    @State private var showAbout = false
    @State private var showNewFile = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

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
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showNewFile) {
                    NewFileSheet { url in
                        navigationPath.append(url)
                    }
                    .environment(vm)
                }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if UserDefaults.standard.data(forKey: "rootFolderBookmark") == nil {
                vm.needsFolderPicker = true
            }
        }) {
            OnboardingView()
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
