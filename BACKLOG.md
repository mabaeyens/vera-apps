# Vera — Backlog

## Phase status

- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** ✅ All items complete
- **Phase 4** ✅ All items complete
- **Phase 5** 🔄 In progress

---

## Phase 5 — Open

1. **Folder selection delay / no activity signal** — partially fixed; full spec in `specs/bug-slow-folder-loading.md`

---

## Recently fixed

- ✅ **iOS UI revamp** — preview mode is clean (title + Edit only); working mode has a scrollable formatting bar above the keyboard (undo/redo, bold/italic/~~strike/`code`, heading/list/quote, Atlas, ··· menu with font size + reference + icon help); macOS font size ± consolidated into one menu
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
