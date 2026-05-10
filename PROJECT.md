# Vera — Project Reference

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

No server, no networking (beyond iCloud sync). 100% local + iCloud.

## Key technical decisions

- **File access — macOS:** No App Sandbox. Folder picker (`.fileImporter`) on first launch; URL persisted as security-scoped bookmark (`withSecurityScope`) in `UserDefaults` key `rootFolderBookmark`.
- **File access — iOS:** Same `.fileImporter` + security-scoped bookmark flow; bookmark options `[]` (no `withSecurityScope`).
- **CloudScanner:** `FileManager()` created in `scan()` (on caller's `@MainActor`), passed into `Task.detached` to avoid implicit `@MainActor` on iOS 26 SDK.
- **Markdown rendering:** MarkdownUI (SPM) — handles tables, code blocks, task lists.
- **Syntax highlighting:** Highlightr (SPM) — `HighlightingTextView` (`UIViewRepresentable`/`NSViewRepresentable`) wraps `UITextView`/`NSTextView` with `CodeAttributedString`.
- **Markdown editing:** `HighlightingTextView` (Phase 3+), not `TextEditor`.
- **Smart Anchor:** Proportional tap-to-offset mapping in `SmartAnchorResolver.swift`. Upgrade to TextKit 2 only if user reports it as jarring.
- **Auto-save:** 500 ms debounce via `Task.sleep`; `NSFileVersion` conflict resolution on read; version cleanup after write.
- **macOS sidebar:** `DisclosureGroup` (not `List(children:)`) so folder labels are clickable. Visibility persisted via `@AppStorage("sidebar.visible")` + computed `Binding<NavigationSplitViewVisibility>`.
- **File switching:** `.id(url)` on `DocumentView` forces SwiftUI to recreate view and `EditorViewModel` on URL change.
- **Context menu (iOS):** `UITextViewDelegate.textView(_:editMenuForTextIn:suggestedActions:)` appends "Format…" and (when selection exists) "Remove Formatting".
- **Context menu (macOS):** `NSTextViewDelegate.textView(_:menu:for:at:)` appends the same items as `NSMenuItem` with explicit `target = self` on the Coordinator.
- **Atlas from context menu:** `EditorViewModel.atlasRequested: Bool` flag observed in `DocumentView` via `.onChange` — avoids direct closure coupling from deep inside the `UIViewRepresentable` coordinator.
- **Connectivity:** `ConnectivityMonitor` wraps `NWPathMonitor` and publishes `isOnline: Bool`. Injected app-wide via `.environment`. Offline: new files and edits still work (saved locally, sync on reconnect); cloud-only file download is disabled.
- **New file creation:** `FileTreeViewModel.createFile(named:in:)` writes an empty `.md` file, then calls `load()` to refresh the tree. `NewFileSheet` (platform-adaptive) exposes filename field + folder picker.

## SPM dependencies

- MarkdownUI: `https://github.com/gonzalezreal/swift-markdown-ui`
- Highlightr: `https://github.com/raspu/Highlightr`
