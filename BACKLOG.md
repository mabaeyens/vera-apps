# Vera — Backlog

## Phase status

- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** ✅ All items complete
- **Phase 4** ✅ All items complete
- **Phase 5** ✅ All items complete

---

## Recently fixed

- ✅ **Slow/stuck folder loading** — CloudScanner now runs off the main thread (`nonisolated`); 10-second scan timeout with `loadFailed` → "Couldn't Load Files" + Try Again; lazy folder expansion (shallow scan per folder on demand)
- ✅ **Flat folder view** — sidebar shows direct .md files + subfolders only; subfolders expand lazily on tap via `scanShallow`
- ✅ **Icon Help view** — `?` sheet listing every toolbar icon with label + description (iOS only; macOS uses `.help()` tooltips)
- ✅ **Edit button cursor position** — `readingScrollFraction` tracked in ViewingModeView; Edit button opens editor near reading position
- ✅ **Double-tap cursor jump** — no custom double-tap gesture in editor; system UITextView/NSTextView handles word selection natively
- ✅ **Finder double-click** — `AppDelegate.application(_:open:)` + `.onOpenURL` + `openExternalURL` handle Finder-opened files on macOS
- ✅ **Greyed .md files in picker** — `fileImporter` accepts `.folder` + `.md` on iOS; macOS has separate Open File picker
- ✅ **iOS UI revamp** — preview mode is clean (title + Edit only); working mode has a formatting bar above the keyboard (bold/italic/heading/Atlas/··· with grouped UIMenu); macOS font size ± consolidated into one menu
- ✅ **Edit in preview mode** — resolved by design: no inline preview editing; tap Edit to enter working mode
- ✅ **Swipe-left delete on iOS sidebar** — swipe-left action on file rows with confirmation alert
- ✅ **Folder name not updated after switching folders**
- ✅ **Keep iCloud files downloaded across sessions**
- ✅ **Blockquote and footnote/superscript rendering**
- ✅ **Cmd+Z undo broken on macOS** — `IsolatedUndoTextView` registered undo in its own isolated manager but the window's undo manager received the actions; Cmd+Z called the empty isolated one. Fix: removed `IsolatedUndoTextView`, use plain `NSTextView` with `allowsUndo = true`; `updateNSView` already bypassed undo clearing via `textStorage.replaceCharacters`.

## Won't fix

- **`^1` footnote/superscript in Atlas** — cannot be delivered
- **Animated V icon** — dropped

## Open bugs

*(none)*

---

## Notes

- Reset folder picker: `defaults delete Vera rootFolderBookmark`
