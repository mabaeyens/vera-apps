#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MacRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAbout = false
    @State private var showIconHelp = false
    @State private var showNewFile = false
    @State private var showGitHub = false
    @State private var gitHubInitialRepo: SavedRepo?
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: Defaults.Key.hasSeenOnboarding)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage(Defaults.Key.tabBarVisible) private var tabBarVisible: Bool = true
    @AppStorage(Defaults.Key.focusMode) private var focusMode: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var vm = vm
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileTreeView(selectedSource: $vm.selectedSource)
                .frame(minWidth: 200)
                .navigationTitle(vm.rootURL?.lastPathComponent ?? "Files")
        } detail: {
            VStack(spacing: 0) {
                if vm.tabs.count >= 1 && tabBarVisible && !focusMode {
                    TabBarView()
                }
                if let source = vm.selectedSource {
                    DocumentView(source: source)
                        .id(source)
                } else {
                    ContentUnavailableView("Select a file", systemImage: "doc.text")
                }
            }
        }
        .onChange(of: focusMode) { _, isFocused in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                columnVisibility = isFocused ? .detailOnly : .all
            }
        }
        .onChange(of: vm.needsFolderPicker) { _, val in if val { openPicker() } }
        .onReceive(NotificationCenter.default.publisher(for: .veraOpenPicker)) { _ in openPicker() }
        .onReceive(NotificationCenter.default.publisher(for: .veraOpenGitHub)) { note in
            gitHubInitialRepo = note.object as? SavedRepo
            showGitHub = true
        }
        .sheet(isPresented: $showGitHub) {
            GitHubBrowserView(initialRepo: gitHubInitialRepo)
                .frame(width: 520, height: 600)
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showNewFile = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New file")
                .accessibilityLabel("New file")
                .disabled(vm.rootURL == nil)
            }
            ToolbarItem(placement: .automatic) {
                Button { openPicker() } label: {
                    Image(systemName: "folder")
                }
                .help("Open folder or file… (⌘O)")
                .accessibilityLabel("Open folder or file")
                .keyboardShortcut("o", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button { gitHubInitialRepo = nil; showGitHub = true } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("Open from GitHub…")
                .accessibilityLabel("Open from GitHub")
            }
            ToolbarItem(placement: .automatic) {
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh")
            }
            // Secondary items live in a single overflow menu, matching iOS.
            ToolbarItem(placement: .automatic) {
                Menu {
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
                .help("More options")
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView(onReset: { vm.resetState() })
                .frame(width: 480, height: 560)
        }
        .sheet(isPresented: $showIconHelp) {
            IconHelpView()
                .frame(width: 480, height: 560)
        }
        .sheet(isPresented: $showNewFile) {
            NewFileSheet { url in vm.openFileInNewTab(url) }
                .environment(vm)
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if BookmarkStore.load() == nil {
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

        panel.begin { response in
            vm.needsFolderPicker = false
            guard response == .OK, let url = panel.url else { return }
            vm.openFile(url)
        }
    }
}
#endif
