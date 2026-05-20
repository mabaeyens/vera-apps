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
- ✅ **Icon Help view** — `?` sheet listing every toolbar icon with label + description (iOS only; macOS uses `.help()` tooltips)
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

## Open bugs

*(none)*

---

## Notes

- Reset folder picker: `defaults delete Vera rootFolderBookmark`
