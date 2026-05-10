# Vera — Implementation Plan

*Created 2026-05-10. Living document — update each phase as it completes.*

---

## Phase 1 — Foundation (iCloud File Access)

### Goal
A working sidebar that lists all `.md` files from the user's iCloud Drive in a collapsible folder tree. Files not yet downloaded show a cloud icon; tapping them triggers download.

### Steps

**1.1 — Xcode project setup**
- Create a new multiplatform SwiftUI app: `Vera`, bundle ID `com.mira.vera`.
- Set minimum deployment: iOS 18.0, macOS 15.0.
- Add SPM package: `MarkdownUI` (from `github.com/gonzalezreal/swift-markdown-ui`, latest release).
- Add entitlement files: `Vera-iOS.entitlements`, `Vera-macOS.entitlements`.
- Enable iCloud Documents capability (container: `iCloud.com.mab.Vera`).
- Enable `com.apple.security.files.user-selected.read-write` on macOS (for Sandbox + iCloud).
- Create the folder structure: `Shared/Models`, `Shared/ViewModels`, `Shared/Views`, `iOS/`, `macOS/`.
- Create GitHub repo `mabaeyens/vera-apps`, push initial commit.

**1.2 — FileNode model** (`Shared/Models/FileNode.swift`)
```swift
enum FileNode: Identifiable {
    case file(id: UUID, name: String, url: URL, downloadState: DownloadState)
    case folder(id: UUID, name: String, children: [FileNode])
}
enum DownloadState { case local, downloading, cloud }
```

**1.3 — iCloud scanner** (`Shared/Models/CloudScanner.swift`)
- `CloudScanner.scan(root:) async throws -> [FileNode]`
- Recursively enumerate `FileManager.default.contentsOfDirectory`.
- Filter: only `.md` extension files.
- Check `URLResourceKey.ubiquitousItemDownloadingStatusKey` per file.
- Return sorted tree: folders first, then files, both alphabetically.

**1.4 — FileTreeViewModel** (`Shared/ViewModels/FileTreeViewModel.swift`)
- `@MainActor final class FileTreeViewModel: ObservableObject`
- `@Published var roots: [FileNode] = []`
- `@Published var isLoading = false`
- `func load() async` — calls `CloudScanner.scan`, updates `roots`.
- `func download(_ url: URL)` — calls `FileManager.startDownloadingUbiquitousItem(at:)`.
- `func refresh()` — re-scan (called on `NSMetadataQuery` notifications).

**1.5 — FileTreeView** (`Shared/Views/FileTreeView.swift`)
- Recursive `List` / `OutlineGroup` rendering `FileNode` tree.
- Cloud-only files show `Image(systemName: "icloud.and.arrow.down")`.
- Tapping a cloud-only file calls `viewModel.download(_:)` and shows a progress indicator.
- Tapping a local file emits a selection (via `@Binding<URL?> selectedURL`).

**1.6 — Platform entry points**
- `macOS/MacRootView.swift`: `NavigationSplitView` — sidebar: `FileTreeView`, center: placeholder "Select a file".
- `iOS/iOSRootView.swift`: `NavigationStack` — root: `FileTreeView`, detail: pushed `DocumentView` (stub).

**1.7 — NSMetadataQuery watcher** (`Shared/Models/CloudScanner.swift` or separate)
- Start an `NSMetadataQuery` scoped to `NSMetadataQueryUbiquitousDocumentsScope`.
- On `NSMetadataQueryDidUpdateNotification`, call `viewModel.refresh()`.
- This ensures the tree updates when iCloud syncs files in or out.

### Tests (Phase 1)

| Test | How |
|------|-----|
| `FileNode` sorts folders before files | Unit test on `CloudScanner` with a mocked directory listing |
| Duplicate filenames in different folders have different IDs | Unit test: two nodes with same `name` but different `url` must have different `id` |
| Cloud-only files set `downloadState = .cloud` | Unit test: mock `URLResourceKey` returning `notDownloaded` |
| `FileTreeView` shows the cloud icon for `.cloud` state | SwiftUI Preview — visual verification |
| Build passes on iOS Simulator and macOS | `xcodebuild` — automated in every session |

---

## Phase 2 — Viewing & Editing Engine

### Goal
Tapping a file renders it in MarkdownUI (ViewingMode). Double-tap or Edit button switches to a `TextEditor` (EditingMode). The cursor lands at approximately the tapped position ("Smart Anchor").

### Steps

**2.1 — DocumentStore** (`Shared/Models/DocumentStore.swift`)
- `actor DocumentStore`
- `func read(_ url: URL) async throws -> String`
- `func write(_ url: URL, content: String) async throws`
- Handles `FileManager.startDownloadingUbiquitousItem` if needed before read.

**2.2 — EditorViewModel** (`Shared/ViewModels/EditorViewModel.swift`)
- `@MainActor final class EditorViewModel: ObservableObject`
- `@Published var mode: EditorMode = .viewing`  (`enum EditorMode { case viewing, editing }`)
- `@Published var rawText: String = ""`
- `@Published var isDirty = false`
- `var url: URL`
- `func load() async` — reads via `DocumentStore`
- `func enterEditMode(anchorPoint: CGPoint?)` — sets `mode = .editing`, stores anchor for Smart Anchor
- `func exitEditMode()` — sets `mode = .viewing`
- Auto-save: `$rawText` debounced 500 ms via Combine → `DocumentStore.write`

**2.3 — ViewingModeView** (`Shared/Views/ViewingModeView.swift`)
- Renders `rawText` with `MarkdownUI.Markdown(rawText)`
- Overlay gesture: `TapGesture(count: 2)` → `viewModel.enterEditMode(anchorPoint: location)`
- "Edit" toolbar button → same call

**2.4 — EditingModeView** (`Shared/Views/EditingModeView.swift`)
- `TextEditor(text: $viewModel.rawText)`
- "Done" / "Preview" toolbar button → `viewModel.exitEditMode()`
- On appear: apply Smart Anchor (see 2.5)

**2.5 — SmartAnchorResolver** (`Shared/Models/SmartAnchorResolver.swift`)

The Smart Anchor maps a `CGPoint` from the MarkdownUI rendered view to a character offset in the raw string, then scrolls the `TextEditor` to that line.

Algorithm:
1. MarkdownUI renders via TextKit 2 internally. We cannot directly query its layout.
2. **Approximation approach (Phase 2.0):** count rendered lines proportionally.
   - Capture the tap's Y position relative to the scroll view height.
   - Estimate the character offset as `rawText.count × (tapY / viewHeight)`.
   - Place cursor at that offset.
3. **Exact approach (Phase 2.1, if needed):** wrap `UITextView`/`NSTextView` directly using `UIViewRepresentable`, expose `NSTextLayoutManager`, query `textLayoutFragment(for: CGPoint)` → character offset.

Start with the approximation. Upgrade to exact only if user feedback calls it out.

**2.6 — DocumentView** (`Shared/Views/DocumentView.swift`)
- Composes `ViewingModeView` and `EditingModeView` based on `viewModel.mode`
- Toolbar: Edit/Done button, file title

### Tests (Phase 2)

| Test | How |
|------|-----|
| `DocumentStore.read` returns file contents | Unit test with a temp `.md` file |
| `DocumentStore.write` persists changes | Unit test: write, read back, compare |
| Auto-save fires after 500 ms of inactivity | Unit test: set `rawText`, advance Combine scheduler, verify `DocumentStore.write` called |
| `EditorViewModel.mode` transitions correctly | Unit test state machine |
| Smart Anchor offset is within bounds | Unit test: anchor at 0,0 → offset 0; anchor at bottom → offset near `rawText.count` |
| `ViewingModeView` renders `# Hello` as a heading | SwiftUI Preview — visual verification |
| Build passes on both platforms | `xcodebuild` |

---

## Phase 3 — Atlas & Polish

### Goal
A retractable "Atlas" drawer with tap-to-insert Markdown syntax elements. Syntax highlighting in EditingMode. Full auto-save with conflict handling.

### Steps

**3.1 — AtlasItem model** (`Shared/Models/AtlasItem.swift`)
```swift
struct AtlasItem: Identifiable {
    let id = UUID()
    let category: String
    let label: String       // "Bold"
    let syntax: String      // "**text**"
    let cursorOffset: Int   // offset from start where cursor should land after insert
}
```

**3.2 — AtlasDrawer** (`Shared/Views/AtlasDrawer.swift`)
- Retractable bottom sheet (iOS: `.sheet` or `.presentationDetents`)
- macOS: trailing panel in `NavigationSplitView`
- Categories: Basics, Structure, Media, Advanced (see spec §2.C)
- Tap item → calls `viewModel.insert(item:)`

**3.3 — Insert logic in EditorViewModel**
- `func insert(_ item: AtlasItem)` — inserts `item.syntax` at current cursor position, moves cursor by `item.cursorOffset`.

**3.4 — Syntax highlighting**
- Use `NSMutableAttributedString` + regex to colorize headers (`#`), bold (`**`), italic (`*`), links, code spans.
- Wrap `UITextView`/`NSTextView` in `UIViewRepresentable`/`NSViewRepresentable` for full TextKit control.
- Color palette: system `.label` with accent colors from Vera's design language (minimal, dark-mode aware).

**3.5 — Auto-save robustness**
- Handle `NSFileCoordinator` writes to avoid iCloud conflicts.
- Show a subtle "Saved" / "Saving…" indicator in the toolbar.
- On conflict: use `NSFileVersion` to present a diff and let the user choose.

**3.6 — UI polish**
- App icon (Design/AppIcon.svg)
- Onboarding screen (first launch only) explaining iCloud access
- Empty state: "No Markdown files found in iCloud Drive"
- Accessibility: `accessibilityLabel` on all interactive elements

### Tests (Phase 3)

| Test | How |
|------|-----|
| `AtlasItem` insert places cursor correctly | Unit test: insert `**text**` (cursorOffset: 2), verify cursor at index 2 |
| All Atlas categories have at least one item | Unit test on the static `AtlasItem` catalog |
| Syntax highlighting regex matches `# Header` | Unit test |
| Auto-save does not fire if text unchanged | Unit test: load, do not mutate, advance scheduler — `DocumentStore.write` NOT called |
| Full smoke check (manual) | Build and run on device; verify file tree, open file, edit, atlas |

---

## Cross-cutting concerns

### What must never change between phases
- `FileNode.url` is always the canonical file identity (not filename).
- `DocumentStore` is the only place that reads/writes files.
- No iCloud container creation — Vera reads the user's existing Drive.

### Edge cases to watch
- Two files with the same name in different folders → same `name`, different `url` → different tree nodes.
- File renamed or deleted while open → `DocumentStore` should surface the error gracefully.
- iCloud Drive not enabled → show an onboarding prompt, not a crash.
- Very large `.md` files (>1 MB) → `TextEditor` performance; consider chunked display.
- Offline (no iCloud sync) → local files still work; cloud-only files show error on download attempt.

### Acceptance criteria (all phases)
- [ ] App launches on both iOS simulator and macOS without errors
- [ ] iCloud `.md` files appear in the sidebar
- [ ] Tapping a local file opens it in MarkdownUI
- [ ] Editing and saving round-trips correctly (open → edit → close → reopen → same content)
- [ ] Atlas inserts syntax at cursor
- [ ] No force-unwrap crashes on empty drive or non-existent files
