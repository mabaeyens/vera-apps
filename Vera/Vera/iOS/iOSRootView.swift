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
    @AppStorage("tabBarVisible") private var tabBarVisible: Bool = true

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
                                if vm.tabs.count >= 1 && tabBarVisible { TabBarView() }
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
                        if vm.tabs.count >= 1 && tabBarVisible { TabBarView() }
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
                    Task { @MainActor in vm.openFile(url) }
                }
            }
            return true
        }
        .alert(item: Binding(
            get: { vm.fileOpenError },
            set: { vm.fileOpenError = $0 }
        )) { error in
            Alert(title: Text("Cannot Open File"), message: Text(error.localizedDescription))
        }
        // Forward vm-driven triggers (onboarding completion, reset) into local @State.
        .onChange(of: vm.needsFolderPicker) { _, val in if val { showFolderPicker = true } }
        .onReceive(NotificationCenter.default.publisher(for: .veraOpenPicker)) { _ in showFolderPicker = true }
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
                if vm.tabs.count >= 1 {
                    Button { tabBarVisible.toggle() } label: {
                        Label(
                            tabBarVisible ? "Hide Tab Bar" : "Show Tab Bar",
                            systemImage: tabBarVisible ? "chevron.compact.up" : "chevron.compact.down"
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}
#endif
