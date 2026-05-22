# Vera Stability Spec — File Opening & Highlightr Hardening

## Problem statement

Vera crashes when opened from Claude Desktop (double-click on a generated `.md` file):

```
Highlightr/CodeAttributedString.swift:65: Fatal error: Unexpectedly found nil while unwrapping an Optional value
```

Root cause: on a cold-launch triggered by an external app, the SwiftUI view hierarchy is constructed and `HighlightingTextView.makeNSView` / `makeUIView` runs while Highlightr's SPM bundle resource loading is still unreliable. `CodeAttributedString()` force-unwraps a theme bundle at init time and kills the process.

Beyond this crash, file opening has multiple entry points with no shared validation layer, making it easy for any one path to produce a bad state (nil `selectedURL`, wrong root, silent failure).

---

## Goals

1. Vera must never crash on file open, regardless of entry point or launch condition.
2. Every file-open entry point must funnel through one validated code path.
3. Highlightr failures must degrade gracefully, not crash.
4. The user gets a visible error (not a crash or silent blank) when something goes wrong.

---

## Part 1 — Highlightr crash fix

### What's happening

`CodeAttributedString()` internally force-unwraps the result of loading a theme bundle resource. Under SPM this resource lookup can return `nil` on cold launch because the bundle's `principalClass` hasn't been exercised yet, or because the `Bundle.module` accessor fails when called from a non-main thread.

`makeNSView` / `makeUIView` are called synchronously on the main thread during the first layout pass, which happens immediately on cold launch — before anything has had a chance to warm up.

### Fix: lazy, guarded Highlightr initialization with plain-text fallback

**Step 1 — Warm the bundle before any view is shown.**

In `VeraApp.init()` (or earliest possible point), fire a no-op Highlightr call on the main thread so the bundle is loaded before any editor view appears:

```swift
// In VeraApp, before body is evaluated
init() {
    HighlightrWarmup.prime()
}
```

```swift
// HighlightrWarmup.swift
import Highlightr

enum HighlightrWarmup {
    static func prime() {
        // Forces bundle load on the main thread at a safe time.
        _ = Highlightr()
    }
}
```

**Step 2 — Guard `CodeAttributedString` construction.**

`CodeAttributedString()` does not have a failable initializer, but `Highlightr()` does (`init?()` returns `nil` when the bundle fails). Wrap the entire editor view construction in a guard:

In `HighlightingTextView.makeNSView` / `makeUIView`:

```swift
// Before constructing CodeAttributedString, verify Highlightr can init
guard Highlightr() != nil else {
    // Return a plain NSScrollView/UITextView without syntax highlighting
    return makePlainFallbackView(context: context)
}
let textStorage = CodeAttributedString()
```

**Step 3 — Catch theme-loading failures.**

`setTheme(to:)` returns `Bool` but is currently discarded. Log the failure so it's visible in crash logs; fall back to a known-safe theme:

```swift
let themeSet = textStorage.highlightr.setTheme(to: "atom-one-light")
if !themeSet {
    _ = textStorage.highlightr.setTheme(to: "default")
}
```

**Step 4 — Move Highlightr off-view for very large files.**

Files over ~200 KB should use a plain `NSTextView`/`UITextView` without `CodeAttributedString` — Highlightr rehighlights the full document on every keystroke and has caused freezes on large files. Gate this in `DocumentView`:

```swift
// Threshold: 200_000 UTF-8 bytes
let useHighlightr = (content.utf8.count < 200_000)
```

---

## Part 2 — Unified file-open coordinator

### Current state

There are at least four entry points, each with slightly different logic:

| Entry point | Code path |
|---|---|
| External app (Claude Desktop, Finder double-click) | `AppDelegate.application(_:open:)` → Notification → `openExternalURL` |
| `onOpenURL` | `openExternalURL` |
| Toolbar folder button / Cmd+O | `NSOpenPanel` → `openStandaloneFile` or `setRoot` |
| Drag and drop | Not implemented — silently ignored |
| iOS Files app | `onOpenURL` only |

`openExternalURL` and `openStandaloneFile` have overlapping but subtly different logic. Security-scoped resource access is started but never stopped. There's no validation that the URL points to a readable `.md` file before it becomes `selectedURL`.

### Fix: single `FileOpenCoordinator` that all entry points call

Add a `FileOpenCoordinator` (could be a method group on `FileTreeViewModel`) that handles every case:

```swift
// FileTreeViewModel — replaces openExternalURL, openStandaloneFile
func openFile(_ url: URL) {
    let validated = validate(url)           // Step 1
    let accessed  = beginAccess(validated)  // Step 2
    guard accessed else {
        fileOpenError = .accessDenied(url)
        return
    }
    route(validated)                        // Step 3
}
```

**Step 1 — Validate.**

```swift
private func validate(_ url: URL) -> URL? {
    // Resolve symlinks so path comparisons are canonical
    let resolved = url.resolvingSymlinksInPath()
    // Must exist and be a regular file
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir),
          !isDir.boolValue else { return nil }
    // Must be .md or .markdown
    guard ["md", "markdown"].contains(resolved.pathExtension.lowercased()) else { return nil }
    return resolved
}
```

**Step 2 — Security-scoped access.**

Track active security-scoped resources so they can be released when the tab closes:

```swift
private var accessedURLs: Set<URL> = []

private func beginAccess(_ url: URL) -> Bool {
    if accessedURLs.contains(url) { return true }
    let ok = url.startAccessingSecurityScopedResource()
    if ok { accessedURLs.insert(url) }
    return ok
}

func releaseAccess(_ url: URL) {
    guard accessedURLs.contains(url) else { return }
    url.stopAccessingSecurityScopedResource()
    accessedURLs.remove(url)
}
```

Call `releaseAccess` from `closeTab` and `deleteFile`.

**Step 3 — Route.**

```swift
private func route(_ url: URL) {
    if let root = rootURL, url.path.hasPrefix(root.path) {
        // File is inside the current root — select it in the tree
        openFileInActiveTab(url)
    } else if rootURL == nil {
        // No root set — open file's folder as root, then select file
        pendingExternalURL = url
        setRoot(url.deletingLastPathComponent())
    } else {
        // File is outside the current root — open as standalone
        addStandaloneAndSelect(url)
    }
}
```

### Cmd+O / keyboard shortcut

Wire `⌘O` as a keyboard shortcut on macOS that calls `openPicker()` from anywhere in the app (not just when the toolbar button is visible). Add to `MacRootView`:

```swift
.keyboardShortcut("o", modifiers: .command)
```

and on the `openPicker` button, or via a `Commands` block in `VeraApp`.

The `NSOpenPanel` should also allow selecting `.markdown` in addition to `.md`:

```swift
panel.allowedContentTypes = [
    .folder,
    UTType(filenameExtension: "md")       ?? .plainText,
    UTType(filenameExtension: "markdown") ?? .plainText
]
```

### Drag and drop

Implement `onDrop` in both `MacRootView` and `iOSRootView`. Accept `public.file-url` and `public.plain-text` providers:

```swift
.onDrop(of: [.fileURL], isTargeted: nil) { providers in
    for provider in providers {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in vm.openFile(url) }
        }
    }
    return true
}
```

On macOS, also handle `NSPasteboard` drops into the sidebar `FileTreeView`.

### iOS — Files app and Share extension

iOS opens files via `onOpenURL`. The existing path is correct but missing validation. Route through `openFile(_:)` instead of calling `openExternalURL` directly.

### Error presentation

Add a `fileOpenError` property to `FileTreeViewModel`:

```swift
enum FileOpenError: LocalizedError {
    case accessDenied(URL)
    case notMarkdown(URL)
    case fileNotFound(URL)

    var errorDescription: String? { ... }
}

@Published var fileOpenError: FileOpenError? = nil
```

Present it with `.alert(item: $vm.fileOpenError)` in both root views.

---

## Part 3 — Cold launch sequence

When Vera is launched by an external app (not already running):

1. `AppDelegate.application(_:open:)` fires before SwiftUI's `body` is evaluated.
2. The notification is posted but `fileTreeVM` may not be listening yet.
3. `onOpenURL` fires after `body` but before `task { await vm.load() }` completes.

**Fix: hold the URL until the app is ready.**

`openExternalURL` already has `pendingExternalURL` for the case where the root isn't loaded. Extend this to also handle the case where the app hasn't started loading at all:

```swift
// In openFile(_:), if isLoading is true or roots is empty and rootURL != nil:
pendingExternalURL = url
// load() already drains pendingExternalURL when it completes — no change needed there.
```

The existing `load()` already drains `pendingExternalURL` at the end. Verify the drain happens after `openFileInActiveTab` is called (it does, line 115–118 in `FileTreeViewModel.swift`). This path is correct; just ensure `openFile` feeds into it rather than `openFileInActiveTab` bypassing the queue.

---

## Part 4 — Regression test checklist (manual)

Before each release, verify these scenarios on both platforms:

**macOS**
- [ ] Cold launch by double-clicking `.md` in Finder
- [ ] Cold launch from Claude Desktop "Open in Vera"
- [ ] Warm launch, then `⌘O` to open a file outside the current root
- [ ] Warm launch, then `⌘O` to open a folder
- [ ] Drag `.md` file onto the Vera window when no root is set
- [ ] Drag `.md` file onto the Vera window when root is set (file inside root)
- [ ] Drag `.md` file onto the Vera window when root is set (file outside root)
- [ ] Open a very large `.md` file (>200 KB) — no freeze, no crash
- [ ] Open a non-`.md` file — graceful error, no crash
- [ ] Highlightr theme switch (dark/light) without crash

**iOS**
- [ ] Open `.md` from Files app (cold launch)
- [ ] Open `.md` from Files app (warm launch)
- [ ] Open file shared via Share Sheet
- [ ] Open file from iCloud Drive (cloud state, needs download)

---

## Implementation order

1. **Highlightr warmup + guard** (Part 1, Steps 1–3) — fixes the reported crash. One file change in `VeraApp`, one in `HighlightingTextView`. Low risk.
2. **`openFile` coordinator + validation** (Part 2) — replaces `openExternalURL` / `openStandaloneFile`. Medium risk; touch `FileTreeViewModel` and both root views.
3. **Security-scoped resource tracking** (Part 2, Step 2) — prevents access leaks.
4. **Drag and drop** (Part 2) — new capability, no regression risk.
5. **`⌘O` keyboard shortcut** (Part 2) — one line.
6. **Error presentation** (Part 2, error section) — UX polish, no logic risk.
7. **Large-file plain-text gate** (Part 1, Step 4) — performance, do last.
