#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct MacRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedURL: URL?
    @State private var showAbout = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some View {
        @Bindable var vm = vm
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
                    ToolbarItem(placement: .automatic) {
                        Button { showAbout = true } label: {
                            Image(systemName: "info.circle")
                        }
                        .help("About Vera")
                    }
                }
                .sheet(isPresented: $showAbout) {
                    AboutView()
                        .frame(width: 480, height: 520)
                }
        } detail: {
            if let url = selectedURL {
                DocumentView(url: url)
                    .id(url)
            } else {
                ContentUnavailableView("Select a file", systemImage: "doc.text")
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if UserDefaults.standard.data(forKey: "rootFolderBookmark") == nil {
                vm.needsFolderPicker = true
            }
        }) {
            OnboardingView()
                .frame(width: 440, height: 620)
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
