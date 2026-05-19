# Vera

A reading-first Markdown viewer and editor for iOS and macOS. Part of the Mira ecosystem.

**Zero configuration.** No vaults, no projects. Vera is a transparent window into your iCloud Drive — it shows every `.md` file you already have.

## Features

- **Browse** — recursive file tree of every `.md` file in your chosen folder (iCloud or local); folder name shown in title bar
- **Read** — rendered Markdown via MarkdownUI (tables, code blocks, task lists)
- **Edit** — syntax-highlighted editor; double-tap to switch from view to edit mode
- **Font size** — A− / A+ toolbar buttons adjust editor font size per-session
- **Atlas** — tap-to-insert syntax snippets; accessible from the toolbar or the text context menu
- **Remove Formatting** — strip Markdown from selected text via the context menu
- **New file** — create `.md` files in any folder directly from the sidebar
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
- **Markdown rendering:** MarkdownUI (SPM) — handles tables, code blocks, task lists.
- **Syntax highlighting:** Highlightr (SPM) — `HighlightingTextView` (`UIViewRepresentable`/`NSViewRepresentable`) wraps `UITextView`/`NSTextView` with `CodeAttributedString`.
- **Auto-save:** 500 ms debounce via `Task.sleep`; `NSFileVersion` conflict resolution on read; version cleanup after write.
- **macOS sidebar:** `DisclosureGroup` (not `List(children:)`) so folder labels are clickable. Collapse reverted via `onChange(of: columnVisibility)` guard — toolbar button is the only way to hide.
- **File switching:** `.id(url)` on `DocumentView` forces SwiftUI to recreate the view and `EditorViewModel` on URL change.
- **Context menu (iOS):** `UITextViewDelegate.textView(_:editMenuForTextIn:suggestedActions:)` appends "Format…" and "Remove Formatting".
- **Context menu (macOS):** `NSTextViewDelegate.textView(_:menu:for:at:)` appends the same items as `NSMenuItem` with explicit `target = self` on the Coordinator.
- **Atlas from context menu:** `EditorViewModel.atlasRequested: Bool` flag observed in `DocumentView` via `.onChange` — avoids direct closure coupling from inside the `UIViewRepresentable` coordinator.
- **Connectivity:** `ConnectivityMonitor` wraps `NWPathMonitor`, publishes `isOnline: Bool`, injected app-wide via `.environment`. Cloud-only file download disabled when offline.
- **New file creation:** `FileTreeViewModel.createFile(named:in:)` writes an empty `.md` file, then calls `load()` to refresh the tree.
- **UserDefaults domain:** `Vera` (not `com.mab.Vera`). Reset folder: `defaults delete Vera rootFolderBookmark`.

## SPM dependencies

- [`swift-markdown-ui`](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering in ViewingMode
- [`Highlightr`](https://github.com/raspu/Highlightr) — Syntax highlighting in EditingMode
