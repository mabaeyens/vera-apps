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
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: Defaults.Key.hasSeenOnboarding)
    @State private var showIconHelp = false
    // Local @State mirrors of vm picker flags.
    // @Observable property reads via @Bindable are lazy closures — they don't register
    // as dependencies during body evaluation, so SwiftUI never re-renders on change.
    // Local @State always invalidates the owner view on write, which is what we need.
    @State private var showFolderPicker = false
    @State private var showGitHub = false
    @State private var gitHubInitialRepo: SavedRepo?
    @AppStorage(Defaults.Key.tabBarVisible) private var tabBarVisible: Bool = true

    var body: some View {
        @Bindable var vm = vm
        Group {
            if horizontalSizeClass == .compact {
                // On iPhone, use a real NavigationStack so DocumentView is pushed as a proper
                // navigation destination — only then does its .toolbar connect to the nav bar.
                // NavigationSplitView in compact mode collapses differently and the detail
                // column's toolbar items don't reach the navigation bar.
                NavigationStack {
                    FileTreeView(selectedSource: $vm.selectedSource)
                        .navigationTitle(vm.rootURL?.lastPathComponent ?? "Files")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar { sharedToolbar }
                        .navigationDestination(item: $vm.selectedSource) { source in
                            VStack(spacing: 0) {
                                if vm.tabs.count >= 1 && tabBarVisible { TabBarView() }
                                DocumentView(source: source).id(source)
                            }
                        }
                }
            } else {
                // iPad: standard split view
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    FileTreeView(selectedSource: $vm.selectedSource)
                        .navigationTitle(vm.rootURL?.lastPathComponent ?? "Files")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar { sharedToolbar }
                } detail: {
                    VStack(spacing: 0) {
                        if vm.tabs.count >= 1 && tabBarVisible { TabBarView() }
                        if let source = vm.selectedSource {
                            DocumentView(source: source).id(source)
                        } else {
                            ContentUnavailableView("Select a file", systemImage: "doc.text")
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [
                .folder,
                UTType(filenameExtension: "md")       ?? .plainText,
                UTType(filenameExtension: "markdown") ?? .plainText,
            ]
        ) { result in
            showFolderPicker = false
            vm.needsFolderPicker = false
            if case .success(let url) = result {
                vm.openFile(url)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    let accessing = url.startAccessingSecurityScopedResource()
                    Task { @MainActor in
                        vm.openFile(url)
                        if accessing { url.stopAccessingSecurityScopedResource() }
                    }
                }
            }
            return true
        }
        .alert(
            "Cannot Open File",
            isPresented: Binding(
                get: { vm.fileOpenError != nil },
                set: { if !$0 { vm.fileOpenError = nil } }
            ),
            presenting: vm.fileOpenError
        ) { _ in
            Button("OK", role: .cancel) { vm.fileOpenError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        // Forward vm-driven triggers (onboarding completion, reset) into local @State.
        .onChange(of: vm.needsFolderPicker) { _, val in if val { showFolderPicker = true } }
        .onReceive(NotificationCenter.default.publisher(for: .veraOpenPicker)) { _ in showFolderPicker = true }
        .onReceive(NotificationCenter.default.publisher(for: .veraOpenGitHub)) { note in
            gitHubInitialRepo = note.object as? SavedRepo
            showGitHub = true
        }
        .sheet(isPresented: $showGitHub) {
            GitHubBrowserView(initialRepo: gitHubInitialRepo)
        }
        .sheet(isPresented: $showAbout) {
            AboutView(onReset: { vm.resetState() })
        }
        .sheet(isPresented: $showIconHelp) {
            IconHelpView()
        }
        .sheet(isPresented: $showNewFile) {
            NewFileSheet { url in
                vm.openFileInNewTab(url)
            }
            .environment(vm)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if BookmarkStore.load() == nil {
                showFolderPicker = true
            }
        }) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if UserDefaults.standard.bool(forKey: Defaults.Key.pendingReset) {
                    UserDefaults.standard.set(false, forKey: Defaults.Key.pendingReset)
                    vm.resetState()
                }
                Task { await vm.load() }
            }
        }
    }

    @ToolbarContentBuilder
    private var sharedToolbar: some ToolbarContent {
        // Primary actions are visible, not buried in the menu.
        ToolbarItem(placement: .topBarTrailing) {
            Button { showFolderPicker = true } label: {
                Image(systemName: "folder")
            }
            .accessibilityLabel("Open folder or file")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNewFile = true } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel("New file")
            .disabled(vm.rootURL == nil && vm.standaloneFiles.isEmpty)
        }
        // Only genuinely-secondary items stay in the overflow menu.
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { gitHubInitialRepo = nil; showGitHub = true } label: {
                    Label("Open from GitHub…", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Divider()
                if vm.tabs.count >= 1 {
                    Button { tabBarVisible.toggle() } label: {
                        Label(
                            tabBarVisible ? "Hide Tab Bar" : "Show Tab Bar",
                            systemImage: tabBarVisible ? "chevron.compact.up" : "chevron.compact.down"
                        )
                    }
                    Divider()
                }
                Button { showIconHelp = true } label: {
                    Label("Icon Guide", systemImage: "questionmark.circle")
                }
                Button { showAbout = true } label: {
                    Label("About Vera", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More options")
        }
    }
}
#endif
