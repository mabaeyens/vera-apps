#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MacRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAbout = false
    @State private var showNewFile = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
        .onChange(of: vm.needsFolderPicker) { _, val in if val { openPicker() } }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showNewFile = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New file")
                .disabled(vm.rootURL == nil)
            }
            ToolbarItem(placement: .automatic) {
                Button { openPicker() } label: {
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
                openPicker()
            }
        }) {
            OnboardingView()
                .frame(width: 440, height: 620)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.load() } }
        }
    }

    private func openPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, UTType(filenameExtension: "md") ?? .plainText]
        panel.begin { response in
            vm.needsFolderPicker = false
            guard response == .OK, let url = panel.url else { return }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { vm.setRoot(url) } else { vm.openStandaloneFile(url) }
        }
    }
}
#endif
