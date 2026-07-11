# Vera -- Project Reference

## Identity

| Field | Value |
|-------|-------|
| App name | Vera |
| Bundle ID | `com.mab.Vera` |
| Xcode project | `Vera/Vera.xcodeproj` |
| Swift | 6 |
| Xcode | 26+ |
| Minimum iOS | 18.0 |
| Minimum macOS | 15.0 |
| GitHub remote | `git@github.com:mabaeyens/vera-apps.git` |

## Source layout

```
Vera/
├── Shared/
│   ├── Models/      # FileNode, CloudScanner, DocumentStore, ConnectivityMonitor,
│   │                #   String+Markdown, DownloadState, BookmarkStore, DocumentSource,
│   │                #   GitHubClient, CredentialStore, RepoListStore, RepoTree (+RepoBrowser),
│   │                #   RepoSeenStore
│   ├── ViewModels/  # FileTreeViewModel, EditorViewModel
│   └── Views/       # FileTreeView, DocumentView, EditingModeView, HighlightingTextView,
│                    #   HighlightrFont, MarkdownFileIcon, AtlasView, CheatSheetView,
│                    #   IconHelpView, NewFileSheet, OnboardingView, AboutView,
│                    #   GitHubBrowserView, GitHubCommitSheet, GitHubDiffView
├── iOS/             # iOSRootView (NavigationStack)
├── macOS/           # MacRootView (NavigationSplitView)
└── Assets.xcassets/
Design/              # vera-icon.svg, mockups
```

## Architecture

```
iCloud Drive / local folder
    └── FileManager recursive scan (@MainActor)
            └── FileTreeViewModel (@Observable @MainActor)
                    ├── iOS:   NavigationStack → DocumentView
                    └── macOS: NavigationSplitView (sidebar | DocumentView)
```

No server, no networking (beyond iCloud sync). 100% local + iCloud.

## Key technical decisions

- **File access -- macOS:** **App Sandbox enabled** (re-enabled 2026-06-21 on GA macOS 26.5.1; the old pre-main crash was a macOS 26 *beta* bug, now resolved — M1 in SECURITY_AUDIT.md). Entitlements (`Vera/Vera/Vera.entitlements`): app-sandbox, user-selected.read-write, files.bookmarks.app-scope, network.client (GitHub), ubiquity-kvstore (repo-list sync). Folder picker (`.fileImporter`) on first launch; URL persisted as a security-scoped bookmark (`withSecurityScope`) in the **Keychain** via `BookmarkStore` (migrated off `UserDefaults` — M2 fixed).
- **File access -- iOS:** Same `.fileImporter` + security-scoped bookmark flow; bookmark options `[]` (no `withSecurityScope`).
- **GitHub (git-native, opt-in):** source-agnostic document model. `DocumentSource` (`.file(URL)` | `.gitHub(GitHubFileRef)`) drives `EditorViewModel`/`DocumentView`/tabs/selection, so repo files behave like local ones. `GitHubClient` (REST: defaultBranch, documentFiles, fileVersion, commitFile, createBranch, openPullRequest, commits/diff). `CredentialStore` keeps the fine-grained PAT in the **Keychain** (device-local, never synced). `RepoListStore` keeps the saved-repo list in `NSUbiquitousKeyValueStore` (iCloud KVS, syncs across devices; token never stored here). `RepoTree`/`RepoBrowser` build + lazily cache each repo's full file tree for inline sidebar browsing. `RepoSeenStore` tracks last-seen SHA per file for the "What Changed" diff. Direct commit refreshes the blob SHA in place; PR path creates a branch, commits, opens the PR.
- **Tabs/selection:** `FileTreeViewModel.selectedSource: DocumentSource?` + `TabEntry.source`; `openInActiveTab`/`openInNewTab` take a `DocumentSource` (`.file` wrappers keep drag-drop / picker call sites unchanged). iCloud-only logic (pin/download) is guarded to the `.file` case; GitHub tabs are session-only.
- **Sidebar:** the local folder and each GitHub repo render as **leading-chevron `DisclosureGroup` rows** (recursive `nodeRow`/`repoNodeRow` return `AnyView` since a recursive `some View` can't self-infer). `.md` leaves use the `MarkdownMark` asset via `MarkdownFileIcon`. Deletion is right-click (macOS) / swipe (iOS) only — no hover trash.
- **Focus Mode:** `@AppStorage("focusMode")` hides the linter + formatting bar everywhere; on macOS `MacRootView` also drops the tab bar and sets `columnVisibility = .detailOnly` while focused.
- **Code font:** `applyMonoFont` (`HighlightrFont.swift`) sets real monospaced regular/bold/italic at every Highlightr `setCodeFont` site — Highlightr's own bold/italic derivation fell back to proportional SF for the system mono family.
- **CloudScanner:** `FileManager()` created in `scan()` (on caller's `@MainActor`), passed into `Task.detached` to avoid implicit `@MainActor` on iOS 26 SDK.
- **Markdown rendering (preview):** Custom `MarkdownAttributedString` builder producing `NSAttributedString`; displayed in non-editable `PreviewTextView`. Code blocks use Highlightr (atom-one-light/dark theme). Tables rendered with `│`-separated columns, bolded header row. MarkdownUI is still a package dependency but no longer used for rendering.
- **Syntax highlighting (editor):** Highlightr (SPM) -- `HighlightingTextView` (`UIViewRepresentable`/`NSViewRepresentable`) wraps `UITextView`/`NSTextView` with `CodeAttributedString`. Warmed via `HighlightrWarmup.prime()` in `VeraApp.init()` to prevent cold-launch nil crash.
- **Markdown editing:** `HighlightingTextView`, not `TextEditor`.
- **Smart Anchor:** Proportional tap-to-offset mapping in `SmartAnchorResolver.swift`. Upgrade to TextKit 2 only if user reports it as jarring.
- **Auto-save:** 500 ms debounce via `Task.sleep`; `NSFileVersion` conflict resolution on read; version cleanup after write.
- **macOS sidebar:** `DisclosureGroup` (not `List(children:)`) so folder labels are clickable. Visibility persisted via `@AppStorage("sidebar.visible")` + computed `Binding<NavigationSplitViewVisibility>`.
- **File switching:** `.id(url)` on `DocumentView` forces SwiftUI to recreate view and `EditorViewModel` on URL change.
- **Context menu (iOS):** `UITextViewDelegate.textView(_:editMenuForTextIn:suggestedActions:)` appends "Format…" and (when selection exists) "Remove Formatting".
- **Context menu (macOS):** `NSTextViewDelegate.textView(_:menu:for:at:)` appends the same items as `NSMenuItem` with explicit `target = self` on the Coordinator.
- **Atlas from context menu:** `EditorViewModel.atlasRequested: Bool` flag observed in `DocumentView` via `.onChange` -- avoids direct closure coupling from deep inside the `UIViewRepresentable` coordinator.
- **Connectivity:** `ConnectivityMonitor` wraps `NWPathMonitor` and publishes `isOnline: Bool`. Injected app-wide via `.environment`. Offline: new files and edits still work (saved locally, sync on reconnect); cloud-only file download is disabled.
- **Tabs:** one `EditorViewModel` per tab; tab bar visible from `count >= 1` (first open file); `NSWindow.allowsAutomaticWindowTabbing = false` + `.handlesExternalEvents(matching: [])` suppress system window-tab chrome and duplicate window creation on macOS; iOS bottom tab bar (max 5 tabs); "+" button posts `.veraOpenPicker` notification; opening a URL already open navigates to that tab.
- **Editability:** `FileKind.isEditable` (true for `.editable`/`.readOnlyText`, false for `.image`/`.binary`) is the single gate for whether a file can enter edit mode — every text/code file Vera can open and syntax-highlight is editable, not just the 4 `DocumentFormat` cases (Markdown/Text/JSON/YAML). `EditorViewModel.canEdit` drives the Edit/Done toolbar button and `enterEditMode()`; `format` (still just the 4 rich cases) now only gates format-*specific* behavior — Markdown auto-fix/lint/Atlas/formatting bar, not editability itself.
- **iOS formatting bar:** `UIInputAccessoryView`-based scrollable bar (44 pt, `secondarySystemBackground`) with undo/redo, inline format buttons (bold, italic, strikethrough, code), block shortcuts (heading, list, quote), Atlas trigger, and a `···` UIMenu for font size and help — shown only for Markdown files (`viewModel.format == .markdown`); other editable file types get a plain syntax-highlighted editor with no formatting chrome, so a stray tap can't insert `**`/`##` into code. iPad's equivalent (`iPadFormattingBar`, a SwiftUI toolbar) gates the same buttons the same way; its font-size buttons are universal, not Markdown-only.
- **Linter:** `String+Markdown.lintMarkdown()` debounced ≥500 ms off main thread; results in `EditorViewModel.lintResults: [LintWarning]`; skips code fences and front matter; toggle in Settings. Auto-fix via `fixMarkdown()` + `applyAutoFix()` on `EditorViewModel`; available in lint panel and editor toolbar. Markdown-only, like the formatting bar.
- **New file creation:** `FileTreeViewModel.createFile(named:in:format:)` writes an empty file of the given `DocumentFormat` (Markdown/Text/JSON/YAML — the "quick create" set, unchanged even though far more file types are editable once they exist), then calls `load()` to refresh the tree. `NewFileSheet` (platform-adaptive) exposes filename field + folder picker. New files open directly in edit mode (`EditorViewModel.load()` sets `mode = .editing` when `rawText.isEmpty && canEdit`).
- **iOS file list navigation:** File rows use `Button` with `.buttonStyle(.plain)` calling `openFileInActiveTab` directly -- `List(selection:)` only fires `onChange` inside `NavigationSplitView`, not `NavigationStack` on iPhone.

## SPM dependencies

- **Highlightr** (`https://github.com/raspu/Highlightr`) — syntax highlighting in editor (`HighlightingTextView`) and preview code blocks (`MarkdownAttributedString`)
- **MarkdownUI** (`https://github.com/gonzalezreal/swift-markdown-ui`) — retained as a package dependency; no longer used for preview rendering (replaced by `PreviewTextView` + `MarkdownAttributedString`); still pulled in transitively

## Privacy

`PrivacyInfo.xcprivacy` exists at `Vera/Vera/PrivacyInfo.xcprivacy` and declares `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1`). The Vera target uses a `PBXFileSystemSynchronizedRootGroup`, so the file is bundled automatically — verified present at `Vera.app/Contents/Resources/PrivacyInfo.xcprivacy` in built products. No manual Xcode target step is needed.