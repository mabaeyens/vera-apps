#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct MacRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAbout = false
    @State private var showNewFile = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    // Local @State so SwiftUI tracks it — @Observable binding via @Bindable is lazy
    // and won't re-render this view when the vm property changes.
    @State private var showPicker = false

    var body: some View {
        @Bindable var vm = vm
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileTreeView(selectedURL: $vm.selectedURL)
                .frame(minWidth: 200)
                .navigationTitle(vm.rootURL?.lastPathComponent ?? "Vera")
        } detail: {
            VStack(spacing: 0) {
                if vm.tabs.count >= 2 {
                    TabBarView()
                }
                if let url = vm.selectedURL {
                    DocumentView(url: url)
                        .id(url)
                } else {
                    ContentUnavailableView("Select a file", systemImage: "doc.text")
                }
            }
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder, UTType(filenameExtension: "md") ?? .plainText]
        ) { result in
            showPicker = false
            vm.needsFolderPicker = false
            if case .success(let url) = result {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir { vm.setRoot(url) } else { vm.openStandaloneFile(url) }
            }
        }
        .onChange(of: vm.needsFolderPicker) { _, val in if val { showPicker = true } }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showNewFile = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New file")
                .disabled(vm.rootURL == nil)
            }
            ToolbarItem(placement: .automatic) {
                Button { showPicker = true } label: {
                    Image(systemName: "folder")
                }
                .help("Open folder or file…")
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
            AboutView(onReset: { vm.resetState() })
                .frame(width: 480, height: 560)
        }
        .sheet(isPresented: $showNewFile) {
            NewFileSheet { url in vm.openFileInActiveTab(url) }
                .environment(vm)
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if UserDefaults.standard.data(forKey: "rootFolderBookmark") == nil {
                showPicker = true
            }
        }) {
            OnboardingView()
                .frame(width: 440, height: 620)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.load() } }
        }
    }
}
#endif
