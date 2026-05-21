#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct iOSRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showAbout = false
    @State private var showNewFile = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var showIconHelp = false
    // Local @State mirrors of vm picker flags.
    // @Observable property reads via @Bindable are lazy closures — they don't register
    // as dependencies during body evaluation, so SwiftUI never re-renders on change.
    // Local @State always invalidates the owner view on write, which is what we need.
    @State private var showFolderPicker = false

    var body: some View {
        @Bindable var vm = vm
        Group {
            if horizontalSizeClass == .compact {
                // On iPhone, use a real NavigationStack so DocumentView is pushed as a proper
                // navigation destination — only then does its .toolbar connect to the nav bar.
                // NavigationSplitView in compact mode collapses differently and the detail
                // column's toolbar items don't reach the navigation bar.
                NavigationStack {
                    FileTreeView(selectedURL: $vm.selectedURL)
                        .navigationTitle(vm.rootURL?.lastPathComponent ?? "Vera")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar { sharedToolbar }
                        .navigationDestination(item: $vm.selectedURL) { url in
                            VStack(spacing: 0) {
                                if vm.tabs.count >= 2 { TabBarView() }
                                DocumentView(url: url).id(url)
                            }
                        }
                }
            } else {
                // iPad: standard split view
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    FileTreeView(selectedURL: $vm.selectedURL)
                        .navigationTitle(vm.rootURL?.lastPathComponent ?? "Vera")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar { sharedToolbar }
                } detail: {
                    VStack(spacing: 0) {
                        if vm.tabs.count >= 2 { TabBarView() }
                        if let url = vm.selectedURL {
                            DocumentView(url: url).id(url)
                        } else {
                            ContentUnavailableView("Select a file", systemImage: "doc.text")
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder, UTType(filenameExtension: "md") ?? .plainText]
        ) { result in
            showFolderPicker = false
            vm.needsFolderPicker = false
            if case .success(let url) = result {
                // Security-scoped access must be started before reading resource values on iOS;
                // without it, isDirectory returns nil and the folder is misrouted to openStandaloneFile.
                _ = url.startAccessingSecurityScopedResource()
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                url.stopAccessingSecurityScopedResource()
                if isDir { vm.setRoot(url) } else { vm.openStandaloneFile(url) }
            }
        }
        // Forward vm-driven triggers (onboarding completion, reset) into local @State.
        .onChange(of: vm.needsFolderPicker) { _, val in if val { showFolderPicker = true } }
        .sheet(isPresented: $showAbout) {
            AboutView(onReset: { vm.resetState() })
        }
        .sheet(isPresented: $showIconHelp) {
            IconHelpView()
        }
        .sheet(isPresented: $showNewFile) {
            NewFileSheet { url in
                vm.openFileInActiveTab(url)
            }
            .environment(vm)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if UserDefaults.standard.data(forKey: "rootFolderBookmark") == nil {
                showFolderPicker = true
            }
        }) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if UserDefaults.standard.bool(forKey: "pendingReset") {
                    UserDefaults.standard.set(false, forKey: "pendingReset")
                    vm.resetState()
                }
                Task { await vm.load() }
            }
        }
    }

    @ToolbarContentBuilder
    private var sharedToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showAbout = true } label: {
                Image(systemName: "info.circle")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button { showIconHelp = true } label: {
                Image(systemName: "questionmark.circle")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showFolderPicker = true } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                Button { showNewFile = true } label: {
                    Label("New File", systemImage: "square.and.pencil")
                }
                .disabled(vm.rootURL == nil)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}
#endif
