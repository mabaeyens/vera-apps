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
│   ├── Models/      # FileNode, CloudScanner, DocumentStore, DownloadState
│   ├── ViewModels/  # FileTreeViewModel, EditorViewModel
│   └── Views/       # FileTreeView, DocumentView, AtlasDrawer, …
├── iOS/             # iOSRootView (NavigationStack)
├── macOS/           # MacRootView (NavigationSplitView)
└── Assets.xcassets/
Design/              # vera-icon.svg, mockups
```

## Architecture

```
iCloud Drive / local folder
    └── FileManager recursive scan (Task.detached)
            └── FileTreeViewModel (@Observable @MainActor)
                    ├── iOS:   NavigationStack → DocumentView
                    └── macOS: NavigationSplitView (sidebar | DocumentView)
```

No server, no networking. 100% local + iCloud.

## Key technical decisions

- **File access — macOS:** No App Sandbox. Folder picker (`.fileImporter`) on first launch; URL persisted as security-scoped bookmark (`withSecurityScope`) in `UserDefaults` key `rootFolderBookmark`.
- **File access — iOS:** Same `.fileImporter` + security-scoped bookmark flow; bookmark options `[]` (no `withSecurityScope`).
- **CloudScanner:** `FileManager()` created in `scan()` (on caller's `@MainActor`), passed into `Task.detached` to avoid implicit `@MainActor` on iOS 26 SDK.
- **Markdown rendering:** MarkdownUI (SPM) — handles tables, code blocks, task lists.
- **Markdown editing:** Native `TextEditor`.
- **Smart Anchor:** Proportional tap-to-offset mapping in `SmartAnchorResolver.swift`. Upgrade to TextKit 2 only if user reports it as jarring.
- **Auto-save:** 500 ms debounce via `Task.sleep`.
- **macOS sidebar:** `DisclosureGroup` (not `List(children:)`) so folder labels are clickable.
- **File switching:** `.id(url)` on `DocumentView` forces SwiftUI to recreate view and `EditorViewModel` on URL change.

## SPM dependencies

- MarkdownUI: `https://github.com/gonzalezreal/swift-markdown-ui`
- Highlightr: `https://github.com/raspu/Highlightr`
