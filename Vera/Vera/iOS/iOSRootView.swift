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
                        .fileImporter(
                            isPresented: $vm.needsFolderPicker,
                            allowedContentTypes: [.folder, UTType(filenameExtension: "md") ?? .plainText]
                        ) { result in
                            if case .success(let url) = result {
                                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                                if isDir { vm.setRoot(url) } else { vm.openStandaloneFile(url) }
                            }
                        }
                        .toolbar {
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
                                Button { showNewFile = true } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .disabled(vm.rootURL == nil)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { vm.needsFilePicker = true } label: {
                                    Image(systemName: "tray.and.arrow.down")
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { vm.needsFolderPicker = true } label: {
                                    Image(systemName: "folder")
                                }
                            }
                        }
                        .navigationDestination(item: $vm.selectedURL) { url in
                            VStack(spacing: 0) {
                                if vm.tabs.count >= 2 { TabBarView() }
                                DocumentView(url: url).id(url)
                            }
                        }
                }
                // File picker at NavigationStack level — always in the view hierarchy
                // regardless of whether the sidebar or document screen is active
                .fileImporter(
                    isPresented: $vm.needsFilePicker,
                    allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText]
                ) { result in
                    if case .success(let url) = result {
                        vm.openStandaloneFile(url)
                    }
                }
            } else {
                // iPad: standard split view
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    FileTreeView(selectedURL: $vm.selectedURL)
                        .navigationTitle(vm.rootURL?.lastPathComponent ?? "Vera")
                        .navigationBarTitleDisplayMode(.large)
                        .fileImporter(
                            isPresented: $vm.needsFolderPicker,
                            allowedContentTypes: [.folder, UTType(filenameExtension: "md") ?? .plainText]
                        ) { result in
                            if case .success(let url) = result {
                                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                                if isDir { vm.setRoot(url) } else { vm.openStandaloneFile(url) }
                            }
                        }
                        .toolbar {
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
                                Button { showNewFile = true } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .disabled(vm.rootURL == nil)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { vm.needsFilePicker = true } label: {
                                    Image(systemName: "tray.and.arrow.down")
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { vm.needsFolderPicker = true } label: {
                                    Image(systemName: "folder")
                                }
                            }
                        }
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
                .fileImporter(
                    isPresented: $vm.needsFilePicker,
                    allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText]
                ) { result in
                    if case .success(let url) = result {
                        vm.openStandaloneFile(url)
                    }
                }
            }
        }
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
                vm.needsFolderPicker = true
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
}
#endif
