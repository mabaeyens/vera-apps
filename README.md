# Vera

A reading-first Markdown viewer and editor for iOS and macOS. Part of the Mira ecosystem.

**Zero configuration.** No vaults, no projects. Vera is a transparent window into your iCloud Drive — it shows every `.md` file you already have.

## Features

- **Browse** — recursive file tree of every `.md` file in your chosen folder (iCloud or local); lazy per-folder expansion; folder name shown in title bar
- **Read** — native `PreviewTextView` (UITextView/NSTextView) with full cross-block selection and rich-text copy; syntax-highlighted fenced code blocks (atom-one theme via Highlightr); structured table rendering; selectable text copies rich text to clipboard
- **Edit** — syntax-highlighted editor; double-tap or Edit button to switch modes; new empty files open directly in edit mode; iOS formatting bar (undo/redo, bold, italic, heading, Atlas, more) slides up with the keyboard
- **Tabs** — tab bar visible from the first open file; "+" button opens file picker; macOS native tab bar suppressed (no system window-tab chrome); iOS bottom tab bar (up to 5 tabs)
- **Font size** — adjustable editor font size per-session
- **Atlas** — tap-to-insert syntax snippets; accessible from the toolbar in both preview and edit mode
- **Linter** — real-time Markdown syntax warnings while editing (debounced, off main thread); toggle in Settings; **Auto-fix** button repairs heading spacing, collapses blank lines, strips trailing whitespace, replaces smart quotes and dashes
- **Remove Formatting** — strip Markdown from selected text via the context menu
- **New file** — create `.md` files in any folder directly from the sidebar
- **Open file** — open any `.md` file directly without selecting a folder first; works from the sidebar or Finder (macOS)
- **Reset** — "Reset Vera" clears folder selection without deleting files; accessible from the About sheet
- **Offline** — edits and new files work without a connection; iCloud syncs on reconnect
- **Dark / light** — adaptive; follows system appearance
- **macOS sidebar** — persistent; only the toolbar button can hide it (never auto-collapses)

## Identity

| Field | Value |
|-------|-------|
| Bundle ID | `com.mab.Vera` |
| Xcode project | `Vera/Vera.xcodeproj` |
| Swift | 6 |
| Xcode | 26+ |
| Minimum iOS | 18.0 |
| Minimum macOS | 15.0 |
| GitHub | `git@github.com:mabaeyens/vera-apps.git` |

## Source layout

```
Vera/
├── Shared/
│   ├── Models/      # FileNode, CloudScanner, DocumentStore, ConnectivityMonitor,
│   │                #   String+Markdown, DownloadState
│   ├── ViewModels/  # FileTreeViewModel, EditorViewModel
│   └── Views/       # FileTreeView, DocumentView, AtlasDrawer,
│                    #   HighlightingTextView, NewFileSheet, OnboardingView, AboutView
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

No server, no networking beyond iCloud sync.

## Key technical decisions

- **File access — macOS:** No App Sandbox (causes pre-main crash on macOS 26 beta). Folder picker (`.fileImporter`) on first launch; URL persisted as security-scoped bookmark (`withSecurityScope`) in `UserDefaults` key `rootFolderBookmark`.
- **File access — iOS:** Same `.fileImporter` + security-scoped bookmark flow; bookmark options `[]` (no `withSecurityScope`).
- **Markdown rendering (preview):** Custom `MarkdownAttributedString` builder producing `NSAttributedString`; displayed in non-editable `PreviewTextView` (`UIViewRepresentable`/`NSViewRepresentable`). Code blocks use Highlightr (atom-one-light/dark). Tables rendered with `│`-separated columns, bolded header row.
- **Syntax highlighting (editor):** Highlightr (SPM) — `HighlightingTextView` wraps `UITextView`/`NSTextView` with `CodeAttributedString`. Warmed on app launch via `HighlightrWarmup.prime()` to prevent cold-launch crash.
- **Auto-save:** 500 ms debounce via `Task.sleep`; `NSFileVersion` conflict resolution on read; version cleanup after write.
- **Tabs:** one `EditorViewModel` per tab; tab bar visible from `count >= 1` (first open file); `NSWindow.allowsAutomaticWindowTabbing = false` suppresses system window-tab bar on macOS; iOS bottom tab bar (max 5 tabs); "+" button posts `.veraOpenPicker` notification to open file picker; opening a URL already open in another tab navigates to that tab instead of duplicating.
- **Linter auto-fix:** `String+Markdown.fixMarkdown()` — collapses 3+ blank lines to 2, ensures blank lines around headings, strips trailing whitespace, replaces smart quotes/dashes with ASCII equivalents. Callable from lint panel or editor toolbar.
- **New file edit mode:** `EditorViewModel.load()` sets `mode = .editing` when `rawText.isEmpty`, so new files open with cursor ready.
- **iOS formatting bar:** `UIInputAccessoryView`-based scrollable bar (44 pt, `secondarySystemBackground`) with undo/redo, inline format buttons (bold, italic, strikethrough, code), block shortcuts (heading, list, quote), Atlas trigger, and a `···` UIMenu for font size and help.
- **Linter:** `String+Markdown.lintMarkdown()` debounced ≥500 ms off main thread; results in `EditorViewModel.lintResults: [LintWarning]`; skips code fences and front matter; toggle in Settings.
- **macOS sidebar:** `DisclosureGroup` (not `List(children:)`) so folder labels are clickable. Collapse reverted via `onChange(of: columnVisibility)` guard — toolbar button is the only way to hide.
- **File switching:** `.id(url)` on `DocumentView` forces SwiftUI to recreate the view and `EditorViewModel` on URL change.
- **Context menu (iOS):** `UITextViewDelegate.textView(_:editMenuForTextIn:suggestedActions:)` appends "Format…" and "Remove Formatting".
- **Context menu (macOS):** `NSTextViewDelegate.textView(_:menu:for:at:)` appends the same items as `NSMenuItem` with explicit `target = self` on the Coordinator.
- **Atlas from context menu:** `EditorViewModel.atlasRequested: Bool` flag observed in `DocumentView` via `.onChange` — avoids direct closure coupling from inside the `UIViewRepresentable` coordinator.
- **Connectivity:** `ConnectivityMonitor` wraps `NWPathMonitor`, publishes `isOnline: Bool`, injected app-wide via `.environment`. Cloud-only file download disabled when offline.
- **New file creation:** `FileTreeViewModel.createFile(named:in:)` writes an empty `.md` file, then calls `load()` to refresh the tree.
- **UserDefaults domain:** `Vera` (not `com.mab.Vera`). Reset folder: `defaults delete Vera rootFolderBookmark`.

## SPM dependencies

- [`swift-markdown-ui`](https://github.com/gonzalezreal/swift-markdown-ui) — retained as SPM dependency but no longer used for preview rendering (replaced by `PreviewTextView` + `MarkdownAttributedString`)
- [`Highlightr`](https://github.com/raspu/Highlightr) — Syntax highlighting in both EditingMode (`HighlightingTextView`) and preview code blocks (`MarkdownAttributedString`)
