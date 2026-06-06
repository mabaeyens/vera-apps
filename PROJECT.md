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

- **File access -- macOS:** No App Sandbox. Folder picker (`.fileImporter`) on first launch; URL persisted as security-scoped bookmark (`withSecurityScope`) in `UserDefaults` key `rootFolderBookmark`.
- **File access -- iOS:** Same `.fileImporter` + security-scoped bookmark flow; bookmark options `[]` (no `withSecurityScope`).
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
- **iOS formatting bar:** `UIInputAccessoryView`-based scrollable bar (44 pt, `secondarySystemBackground`) with undo/redo, inline format buttons (bold, italic, strikethrough, code), block shortcuts (heading, list, quote), Atlas trigger, and a `···` UIMenu for font size and help.
- **Linter:** `String+Markdown.lintMarkdown()` debounced ≥500 ms off main thread; results in `EditorViewModel.lintResults: [LintWarning]`; skips code fences and front matter; toggle in Settings. Auto-fix via `fixMarkdown()` + `applyAutoFix()` on `EditorViewModel`; available in lint panel and editor toolbar.
- **New file creation:** `FileTreeViewModel.createFile(named:in:)` writes an empty `.md` file, then calls `load()` to refresh the tree. `NewFileSheet` (platform-adaptive) exposes filename field + folder picker. New files open directly in edit mode (`EditorViewModel.load()` sets `mode = .editing` when `rawText.isEmpty`).
- **iOS file list navigation:** File rows use `Button` with `.buttonStyle(.plain)` calling `openFileInActiveTab` directly -- `List(selection:)` only fires `onChange` inside `NavigationSplitView`, not `NavigationStack` on iPhone.

## SPM dependencies

**Direct:**
- MarkdownUI: `https://github.com/gonzalezreal/swift-markdown-ui` -- used for preview rendering (`MarkdownDocumentView`) and `CheatSheetView`
- Highlightr: `https://github.com/raspu/Highlightr` -- syntax highlighting in editor (`HighlightingTextView`) and preview code blocks (`CopyableCodeBlock`)

**Transitive (pulled in by MarkdownUI, not used directly):**
- swift-cmark: `https://github.com/apple/swift-cmark` -- C CommonMark parser (MarkdownUI dependency)
- NetworkImage: `https://github.com/gonzalezreal/NetworkImage` -- remote image loading (MarkdownUI dependency)