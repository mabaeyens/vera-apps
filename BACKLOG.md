# Vera — Backlog

## Phase status

- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** ✅ All items complete
- **Phase 4** ✅ All items complete
- **Phase 5** 🔄 In progress

---

## Phase 5

1. ⚠️ **Delete file via swipe left in sidebar** — swipe-left action on file rows; show confirmation alert before deleting; no delete without confirmation
2. **edit in preview mode**, keeping the format of the edited block
3. **animated** V icon
4. delays when selecting other folders - no activity signal
5. folder name not updated after switching folders
6. add contextual format option higher
7. top of keyboard formatting menu like the iOS Notes app?
8. keep downloaded files downloaded across sessions, unless cloud is more updated
9. markdown references rendering issues: blockquote and superindex/footnote
10. **`^1` footnote/superscript syntax not working in Atlas** — inserting via Atlas does nothing or renders incorrectly

---

## Recently fixed

- ✅ **Cmd+Z undo broken on macOS** — `IsolatedUndoTextView` registered undo in its own isolated manager but the window's undo manager received the actions; Cmd+Z called the empty isolated one. Fix: removed `IsolatedUndoTextView`, use plain `NSTextView` with `allowsUndo = true`; `updateNSView` already bypassed undo clearing via `textStorage.replaceCharacters`.

## Open bugs

*(none)*

---

## Notes

- Reset folder picker: `defaults delete Vera rootFolderBookmark`
