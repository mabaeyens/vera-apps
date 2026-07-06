import SwiftUI

private struct PendingCommit: Identifiable {
    let id = UUID()
    let message: String
    let openPR: Bool
    let targetBranch: String
}

struct DocumentView: View {
    let source: DocumentSource
    @State private var viewModel: EditorViewModel
    @State private var showAtlas = false
    @State private var showCheatSheet = false
    @State private var showIconHelp = false
    // GitHub source only.
    @State private var showCommit = false
    @State private var showDiff = false
    @State private var pendingConflict: PendingCommit?
    @State private var latest: GitHubCommit?
    @State private var lastSeen: String?
    @AppStorage(Defaults.Key.editorFontSize) private var fontSize = Defaults.FontSize.default
    @AppStorage(Defaults.Key.focusMode) private var focusMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(GitHubDraftStore.self) private var draftStore

    init(source: DocumentSource) {
        self.source = source
        self._viewModel = State(initialValue: EditorViewModel(source: source))
    }

    init(url: URL) {
        self.init(source: .file(url))
    }

    /// The file changed since the user last opened it (GitHub only).
    private var hasChanges: Bool {
        guard source.isGitHub, let latest, let lastSeen else { return false }
        return latest.sha != lastSeen
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewModel.mode {
                case .viewing:
                    ViewingModeView(viewModel: viewModel)
                case .editing:
                    EditingModeView(
                        viewModel: viewModel,
                        onAtlasRequested: { showAtlas = true },
                        onCheatSheetRequested: { showCheatSheet = true },
                        onIconHelpRequested: { showIconHelp = true }
                    )
                }
            }
        }
        .navigationTitle("")
        .toolbar { toolbarItems }
        .task {
            await viewModel.load()
            if case .gitHub(let ref) = source {
                lastSeen = RepoSeenStore.lastSeen(owner: ref.owner, repo: ref.repo, path: ref.path)
                latest = await viewModel.latestCommit()
                // First visit: record the baseline so later visits can diff.
                if lastSeen == nil, let sha = latest?.sha {
                    RepoSeenStore.markSeen(owner: ref.owner, repo: ref.repo, path: ref.path, sha: sha)
                    lastSeen = sha
                }
            }
        }
        .onDisappear {
            // Flush any edit still inside the autosave debounce so a tab switch /
            // navigation away never drops the last keystrokes. The Task strongly
            // captures viewModel so the write completes even as the view tears down.
            Task { await viewModel.flushPendingSave() }
            if case .gitHub(let ref) = source { draftStore.deregister(ref: ref) }
        }
        .onChange(of: viewModel.rawText) { _, text in
            guard case .gitHub(let ref) = source, let sha = viewModel.blobSHA else { return }
            if viewModel.isUncommitted {
                draftStore.register(ref: ref, text: text, blobSHA: sha)
            }
        }
        .onChange(of: viewModel.isUncommitted) { _, dirty in
            guard case .gitHub(let ref) = source else { return }
            if !dirty { draftStore.deregister(ref: ref) }
        }
        .onChange(of: viewModel.atlasRequested) { _, requested in
            if requested { showAtlas = true; viewModel.atlasRequested = false }
        }
        .sheet(isPresented: $showAtlas) {
            AtlasView(
                onTap: { item in
                    switch item.kind {
                    case .insert:
                        viewModel.insertSnippet(item.syntax)
                    case .wrap(let prefix, let suffix):
                        viewModel.wrapOrInsert(item.syntax, prefix: prefix, suffix: suffix)
                    }
                },
                onRemoveFormatting: { viewModel.stripAtCursor() }
            )
            #if os(iOS)
            .presentationDetents([.large])
            #else
            .frame(width: 380, height: 560)
            #endif
        }
        .sheet(isPresented: $showCheatSheet) {
            CheatSheetView()
                #if os(macOS)
                .frame(width: 480, height: 600)
                #endif
        }
        .sheet(isPresented: $showIconHelp) {
            IconHelpView()
                #if os(macOS)
                .frame(width: 480, height: 560)
                #endif
        }
        .sheet(isPresented: $showCommit) {
            if case .gitHub(let ref) = source {
                GitHubCommitSheet(
                    fileName: source.displayName,
                    branch: ref.branch,
                    fetchBranches: { await viewModel.fetchBranches() },
                    onConflict: { msg, openPR, targetBranch in
                        pendingConflict = PendingCommit(message: msg, openPR: openPR, targetBranch: targetBranch)
                    }
                ) { message, openPR, targetBranch in
                    try await viewModel.commit(message: message, openPR: openPR, targetBranch: targetBranch)
                }
                #if os(macOS)
                .frame(width: 460, height: 380)
                #endif
            }
        }
        .sheet(item: $pendingConflict) { pending in
            if case .gitHub = source {
                ConflictSheet(
                    fileName: source.displayName,
                    pendingMessage: pending.message,
                    pendingOpenPR: pending.openPR,
                    fetchRemoteText: { try await viewModel.fetchRemoteText(branch: pending.targetBranch) },
                    overwrite: { try await viewModel.overwriteCommit(message: pending.message, openPR: pending.openPR, targetBranch: pending.targetBranch) }
                )
                #if os(macOS)
                .frame(width: 460, height: 420)
                #endif
            }
        }
        .sheet(isPresented: $showDiff, onDismiss: refreshSeen) {
            if case .gitHub(let ref) = source, let latest, let lastSeen {
                GitHubDiffView(
                    title: source.displayName,
                    head: latest,
                    loadDiff: { try await viewModel.diff(from: lastSeen, to: latest.sha) },
                    onDone: {
                        RepoSeenStore.markSeen(owner: ref.owner, repo: ref.repo, path: ref.path, sha: latest.sha)
                    }
                )
                #if os(macOS)
                .frame(width: 560, height: 600)
                #endif
            }
        }
    }

    /// After the diff sheet closes (it marked the latest commit seen), reflect that.
    private func refreshSeen() {
        if case .gitHub(let ref) = source {
            lastSeen = RepoSeenStore.lastSeen(owner: ref.owner, repo: ref.repo, path: ref.path)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // iOS: Edit/Done + font size menu (preview mode); edit-mode tools live in the formatting bar
        // macOS: tools in toolbar, font size consolidated into one menu
        ToolbarItem(placement: .primaryAction) {
            switch viewModel.mode {
            case .viewing:
                Button("Edit") { viewModel.enterEditMode() }
            case .editing:
                Button("Done") { viewModel.exitEditMode() }
                    .bold()
            }
        }
        // GitHub source: commit + "what changed" live next to the editor tools.
        if source.isGitHub {
            if hasChanges {
                ToolbarItem(placement: .automatic) {
                    Button { showDiff = true } label: {
                        Image(systemName: "plus.forwardslash.minus")
                    }
                    .help("What Changed")
                    .accessibilityLabel("What changed")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button { showCommit = true } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .help("Commit…")
                .accessibilityLabel("Commit")
                .disabled(viewModel.isLoading)
            }
        }
        if viewModel.mode == .editing {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { focusMode.toggle() }
                } label: {
                    Image(systemName: focusMode ? "circle.dashed.inset.filled" : "circle.dashed")
                }
                .help(focusMode ? "Exit Focus Mode" : "Focus Mode")
                .accessibilityLabel("Focus mode")
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.applyAutoFix()
                } label: {
                    Image(systemName: "wand.and.sparkles")
                }
                .help("Auto-fix formatting")
                .accessibilityLabel("Auto-fix formatting")
            }
        }
        #if os(iOS)
        if viewModel.mode == .viewing {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { fontSize = Defaults.FontSize.increased(from: fontSize) } label: {
                        Label("Larger Text", systemImage: "textformat.size.larger")
                    }
                    Button { fontSize = Defaults.FontSize.decreased(from: fontSize) } label: {
                        Label("Smaller Text", systemImage: "textformat.size.smaller")
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("Text size")
            }
        }
        #endif
        #if os(macOS)
        ToolbarItem(placement: .automatic) {
            Button { showAtlas = true } label: {
                Image(systemName: "paintbrush")
            }
            .help("Format & Snippets")
            .accessibilityLabel("Format and snippets")
        }
        if viewModel.mode == .viewing {
            ToolbarItem(placement: .automatic) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.rawText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy all text")
                .accessibilityLabel("Copy all text")
            }
        }
        ToolbarItem(placement: .automatic) {
            Button { showCheatSheet = true } label: {
                Image(systemName: "book.closed")
            }
            .help("Markdown Reference")
            .accessibilityLabel("Markdown reference")
        }
        ToolbarItem(placement: .automatic) {
            Menu {
                Button { fontSize = Defaults.FontSize.increased(from: fontSize) } label: {
                    Label("Larger Text", systemImage: "textformat.size.larger")
                }
                Button { fontSize = Defaults.FontSize.decreased(from: fontSize) } label: {
                    Label("Smaller Text", systemImage: "textformat.size.smaller")
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            .help("Text Size")
            .accessibilityLabel("Text size")
        }
        #endif
        ToolbarItem(placement: .status) {
            saveIndicator
        }
    }

    @ViewBuilder
    private var saveIndicator: some View {
        switch viewModel.saveState {
        case .saved:
            EmptyView()
        case .saving:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Saving…").font(.caption).foregroundStyle(.secondary)
            }
        case .error(let msg):
            Text(msg).font(.caption).foregroundStyle(.red)
        case .uncommitted:
            Text("Uncommitted").font(.caption).foregroundStyle(.secondary)
        case .committing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Committing…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
