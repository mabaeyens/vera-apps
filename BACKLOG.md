# Vera — Backlog

## Phase status

- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** ✅ All items complete
- **Phase 4** ✅ All items complete
- **Phase 5** ✅ All items complete

---

## Recently fixed

- ✅ **Slow/stuck folder loading** — CloudScanner runs off the main thread (`nonisolated`); 10-second scan timeout → "Couldn't Load Files" + Try Again; lazy shallow scan per folder on demand
- ✅ **Flat folder view** — sidebar shows direct .md files + subfolders only; subfolders expand lazily on tap via `scanShallow`
- ✅ **iOS stuck after load failure** — folder picker always reachable; stale bookmark auto-cleared and picker surfaced after 10s timeout
- ✅ **Icon Help view** — `?` sheet listing every toolbar icon with label + description; available on iOS and macOS; includes Keyboard Shortcuts section
- ✅ **Edit button cursor position** — `readingScrollFraction` tracked in ViewingModeView; Edit button opens editor near reading position
- ✅ **Double-tap cursor jump** — removed custom double-tap gesture; system UITextView/NSTextView handles word selection natively
- ✅ **Finder double-click** — `AppDelegate.application(_:open:)` + `.onOpenURL` + `openExternalURL` handle Finder-opened files on macOS
- ✅ **Greyed .md files in picker** — `fileImporter` accepts `.folder` + `.md` on iOS; macOS has separate Open File picker
- ✅ **iOS UI revamp** — preview mode is clean (title + Edit only); working mode has a formatting bar above the keyboard (bold/italic/heading/Atlas/··· with grouped UIMenu); macOS font size ± consolidated into one menu
- ✅ **Atlas icon duplicate (macOS)** — removed second Atlas button from editing toolbar; single icon in `DocumentView` toolbar covers both modes
- ✅ **Swipe-left delete on iOS sidebar** — swipe-left action on file rows with confirmation alert
- ✅ **Cmd+Z undo broken on macOS** — removed `IsolatedUndoTextView`; plain `NSTextView` with `allowsUndo = true`; `updateNSView` bypasses undo clearing via `textStorage.replaceCharacters`
- ✅ **Multi-tab** — independent editor sessions per tab; macOS native tab strip (Cmd+T); iOS bottom tab bar (max 5 tabs); duplicate-URL guard navigates to existing tab
- ✅ **Copy text in preview** — tap-and-hold on iOS, drag/Cmd+A on macOS; copies plain text (no Markdown symbols)
- ✅ **Reset / purge** — "Reset Vera" clears folder bookmark (not files); confirmation alert; returns to folder-picker state
- ✅ **Markdown linter** — real-time warnings while editing; debounced 500ms off main thread; skips code fences and front matter; toggle in Settings
- ✅ **Folder name not updated after switching folders**
- ✅ **Keep iCloud files downloaded across sessions**
- ✅ **Blockquote and footnote/superscript rendering**

## Won't fix

- **`^1` footnote/superscript in Atlas** — cannot be delivered
- **Animated V icon** — dropped

## Recently fixed (continued)

- ✅ **iPad sidebar "..." menu did nothing** — replaced UIKit overflow with explicit SwiftUI `Menu`; local `@State` triggers for pickers (fixes `@Observable` tracking gap); unified single `fileImporter` for folders + files
- ✅ **iPad formatting bar overlapped sidebar** — skip `inputAccessoryView` on regular width class; SwiftUI `.safeAreaInset` bar constrained to detail column; `onEditingChanged` callback shows/hides bar
- ✅ **macOS folder picker did nothing** — same `@Observable` tracking fix; unified picker for folders + files with `isDirectory` branch
- ✅ **Files sort order** — files first (most recently modified), then folders (most recently modified); `CloudScanner` uses `contentModificationDateKey`
- ✅ **macOS formatting keyboard shortcuts** — `FormattingTextView` subclass overrides `performKeyEquivalent(with:)`; ⌘B bold, ⌘I italic, ⌘⇧X strikethrough, ⌘⇧C inline code
- ✅ **macOS right-click Format menu** — Format submenu at top of context menu with all formatting actions + shortcut labels; Markdown Reference and Icon Help entries
- ✅ **Cheat sheet always expanded** — sections use `Section(isExpanded: .constant(true))`; shortcut badges (⌘B/I/⇧X/⇧C) shown on Emphasis entries
- ✅ **Swift 6 concurrency warnings in CloudScanner** — `stableID` marked `nonisolated`; sort uses local `Dated` struct instead of accessing `FileNode.name` from nonisolated closure

## Recently fixed (session 2026-06-06b — HIG audit)

- ✅ **Nested Button inside Button label (iOS)** — removed inline × button from iOS open-file row; swipe-to-close is the correct iOS pattern
- ✅ **Tab × touch target** — expanded hit area to 44×44pt via `contentShape` (was 14pt, below HIG minimum)
- ✅ **Deprecated `Alert` API** — replaced `Alert(title:message:)` with closure-based `.alert("", isPresented:presenting:)` in both root views
- ✅ **Missing `accessibilityLabel` on icon buttons** — added labels to all icon-only toolbar, tab bar, and sidebar buttons across all views
- ✅ **Brand color invisible in dark mode** — extracted `#1C4C4E` to `BrandTeal` named color asset with light/dark adaptive variants
- ✅ **AboutView dismiss button (iOS)** — replaced ZStack `xmark.circle.fill` overlay with `NavigationStack` + toolbar Done button on iOS; macOS keeps the overlay
- ✅ **Two leading toolbar buttons** — merged About + Icon Guide into the `ellipsis.circle` menu; leading bar now empty
- ✅ **`Section(isExpanded: .constant(true))`** — replaced with plain `Section(title)` in CheatSheetView; removes non-interactive disclosure chevrons
- ✅ **Hardcoded font size in AboutView** — changed `font(.system(size: 28))` to `.font(.title2.weight(.semibold))` for Dynamic Type support
- ✅ **AtlasView button double-highlight** — added `.buttonStyle(.plain)` to list row buttons
- ✅ **Font size via raw UserDefaults** — iPad formatting bar now mutates `@AppStorage` binding directly
- ✅ **Trash icon `.red` on macOS** — button now uses `role: .destructive` for semantic styling
- ✅ **Drag-and-drop missing security scope** — `startAccessingSecurityScopedResource()` called before opening dropped URLs on iOS
- ✅ **Nav title fallback** — changed `"Vera"` fallback to `"Files"` when no folder is open
- ✅ **Onboarding CTA button** — replaced custom-styled button with `.buttonStyle(.borderedProminent) .controlSize(.large)`
- ✅ **NewFileSheet focus on macOS** — `.onAppear { fieldFocused = true }` → `.task { fieldFocused = true }` for post-layout timing

## Recently fixed (session 2026-06-06)

- ✅ **macOS folder picker could not select folders** — removed `.folder` from `NSOpenPanel.allowedContentTypes`; `canChooseDirectories = true` is the correct mechanism; the extra entry conflicted on macOS 26
- ✅ **Sidebar: VSCode-style Open Files section** — sidebar now shows "Open Files" (collapsible, `@AppStorage`-persisted) above the folder tree; driven by `vm.tabs`; active file has accent-color dot; × closes tab on hover (macOS) / swipe (iOS); standalone files appear here instead of a separate "Standalone" section; folder tree section hidden when `vm.roots` is empty
- ✅ **Layout audit** — removed redundant `#if os(macOS) … #else … #endif` block in `DocumentView.swift` (identical branches, default font size 20 on both platforms)

## Recently fixed (session 2026-05-24)

- ✅ **Linter auto-fix** — `String+Markdown.fixMarkdown()` collapses excess blank lines, adds blank lines around headings, strips trailing whitespace, and replaces Unicode smart quotes and dashes with ASCII equivalents; "Auto-fix" button in lint panel; wand toolbar shortcut triggers fix from any file
- ✅ **Always-visible tab bar** — tab bar shows as soon as the first file is open (`count >= 1`); "+" button in tab bar opens the file picker
- ✅ **Suppress system window-tab bar** — `NSWindow.allowsAutomaticWindowTabbing = false` in `VeraApp.init()`; `.handlesExternalEvents(matching: [])` on `WindowGroup` prevents duplicate windows
- ✅ **Syntax highlighting in preview** — `MarkdownAttributedString` uses Highlightr for fenced code blocks; language hint captured from opening fence line; atom-one-light/dark theme; plain-text fallback if Highlightr unavailable
- ✅ **Table rendering in preview** — header row bolded; columns separated by `│`; visually structured without requiring TextKit 2 grid layout
- ✅ **New empty files open in edit mode** — `EditorViewModel.load()` sets `mode = .editing` when `rawText.isEmpty`; cursor is ready immediately on new file creation
- ✅ **iOS file row tap (critical bug fix)** — `List(selection:)` inside `NavigationStack` on iPhone does not fire `onChange`; fixed by wrapping iOS file rows in `Button` with `.buttonStyle(.plain)` that calls `openFileInActiveTab` directly (commit `54e5748`)

## Open bugs

*(none)*

---

## Notes

- Reset folder picker: `defaults delete Vera rootFolderBookmark`
