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
    @State private var showQuickSwitcher = false
    @State private var showGitHub = false
    @State private var gitHubInitialRepo: SavedRepo?
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: Defaults.Key.hasSeenOnboarding)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage(Defaults.Key.focusMode) private var focusMode: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Source of the document in the active tab (nil when nothing is open).
    private var activeSource: DocumentSource? {
        vm.tabs.first(where: { $0.id == vm.activeTabID })?.source
    }

    private var isGitHubDoc: Bool { activeSource?.isGitHub == true }

    var body: some View {
        @Bindable var vm = vm
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileTreeView(selectedSource: $vm.selectedSource)
                .frame(minWidth: 200)
                .navigationTitle("Files")
        } detail: {
            VStack(spacing: 0) {
                if let source = vm.selectedSource, let editor = vm.editor(for: source) {
                    DocumentOrImageView(source: source, editor: editor)
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
        .onReceive(NotificationCenter.default.publisher(for: .veraOpenPicker)) { note in openPicker(startingAt: note.object as? URL) }
        .onReceive(NotificationCenter.default.publisher(for: .veraOpenGitHub)) { note in
            gitHubInitialRepo = note.object as? SavedRepo
            showGitHub = true
        }
        // Menu commands live outside the view tree, so they reach these sheets the same
        // way the toolbar does.
        .onReceive(NotificationCenter.default.publisher(for: .veraNewFile)) { _ in showNewFile = true }
        .onReceive(NotificationCenter.default.publisher(for: .veraQuickOpen)) { _ in showQuickSwitcher = true }
        .onReceive(NotificationCenter.default.publisher(for: .veraIconGuide)) { _ in showIconHelp = true }
        .onReceive(NotificationCenter.default.publisher(for: .veraAbout)) { _ in showAbout = true }
        .sheet(isPresented: $showQuickSwitcher) {
            QuickSwitcherView()
                .environment(vm)
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
            Group {
            ToolbarItem(placement: .automatic) {
                Button { showQuickSwitcher = true } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Go to file… (⌘P)")
                .accessibilityLabel("Go to file")
                .disabled(vm.rootURL == nil)
            }
            ToolbarItem(placement: .automatic) {
                Button { showNewFile = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New file")
                .accessibilityLabel("New file")
                .disabled(vm.rootURL == nil)
            }
            if !isGitHubDoc {
            ToolbarItem(placement: .automatic) {
                Button {
                    NotificationCenter.default.post(name: .veraRevealActiveFile, object: nil)
                } label: {
                    Image(systemName: "scope")
                }
                .help("Reveal active file in sidebar (⇧⌘R)")
                .accessibilityLabel("Reveal active file in sidebar")
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(vm.rootURL == nil)
            }
            }
            ToolbarItem(placement: .automatic) {
                Button { openPicker() } label: {
                    Image(systemName: "folder")
                }
                .help("Open folder or file… (⌘O)")
                .accessibilityLabel("Open folder or file")
                .keyboardShortcut("o", modifiers: .command)
            }
            if !isGitHubDoc {
            ToolbarItem(placement: .automatic) {
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh")
            }
            }
            // Secondary items live in a single overflow menu, matching iOS.
            ToolbarItem(placement: .automatic) {
                Menu {
                    // Document-aware: GitHub entry points show for a GitHub document (or when
                    // nothing is open, so GitHub stays reachable) and hide for a local file.
                    if activeSource == nil || isGitHubDoc {
                        Button { gitHubInitialRepo = nil; showGitHub = true } label: {
                            Label("Open from GitHub…", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    if let source = activeSource, let editor = vm.editor(for: source) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(editor.rawText, forType: .string)
                        } label: {
                            Label("Copy All Text", systemImage: "doc.on.doc")
                        }
                    }
                    SortMenu()
                    Divider()
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
            .veraFlatToolbar()
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
            NewFileSheet { source in vm.openInNewTab(source) }
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
            if phase == .active {
                Task {
                    await vm.load()
                    await vm.reloadAllIfChangedOnDisk()
                }
            } else {
                // Editors now outlive the views that show them, so the per-view
                // `onDisappear` flush no longer covers backgrounding. Write out every
                // open document still inside its autosave debounce.
                Task { await vm.flushAllPendingSaves() }
            }
        }
    }

    private func openPicker(startingAt directory: URL? = nil) {
        let panel = NSOpenPanel()
        panel.directoryURL = directory
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = Defaults.showHiddenFiles

        // The system Open button stays disabled when nothing is selected, so the folder
        // being browsed can't be chosen. This button opens it directly.
        let helper = OpenThisFolderButton(panel: panel)
        panel.accessoryView = helper.view
        panel.isAccessoryViewDisclosed = true

        panel.begin { response in
            vm.needsFolderPicker = false
            if response == .OK, let url = panel.url {
                vm.openFile(url)
            } else if let folder = helper.chosenFolder {
                vm.openFile(folder)
            }
        }
        // Keep the helper alive for the panel's lifetime.
        objc_setAssociatedObject(panel, &OpenThisFolderButton.key, helper, .OBJC_ASSOCIATION_RETAIN)
    }
}

/// Accessory button for `NSOpenPanel`: ends the panel with the directory it is
/// currently showing as the choice.
@MainActor
private final class OpenThisFolderButton: NSObject {
    static var key = 0
    let view: NSView
    private weak var panel: NSOpenPanel?
    private(set) var chosenFolder: URL?

    init(panel: NSOpenPanel) {
        self.panel = panel
        let button = NSButton(title: "Open This Folder", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 0, y: 4, width: 140, height: 28)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 36))
        container.addSubview(button)
        button.frame.origin.x = 10
        view = container
        super.init()
        button.target = self
        button.action = #selector(choose)
    }

    @objc private func choose() {
        guard let panel, let dir = panel.directoryURL else { return }
        chosenFolder = dir
        // End with OK, like the system Open button, so the sandbox's Powerbox grants
        // access to the folder. A cancelled panel grants nothing, so cancel is only the
        // fallback if OK didn't dismiss the panel.
        panel.ok(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak panel] in
            if let panel, panel.isVisible { panel.cancel(nil) }
        }
    }
}
#endif
