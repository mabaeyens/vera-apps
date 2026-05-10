# Vera — Backlog

## Phase status

- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** 🔜 In progress — core features shipped; macOS + iOS fully tested

---

## Phase 3 — Done

1. ✅ **iOS TestFlight distribution** — automated via `/vera-ship` skill
2. ✅ **Markdown cheat sheet** — toolbar book button, MarkdownUI render
3. ✅ **Atlas drawer** — category picker + snippet list, inserts at cursor
4. ✅ **Syntax highlighting** — Highlightr `CodeAttributedString`, light/dark theme
5. ✅ **About screen** — icon, version, description; iOS + macOS
6. ✅ **iOS full test pass** — all 23 tests confirmed on build 4 (2026-05-10)
7. ✅ **macOS full test pass** — all 23 tests confirmed on build 5 (2026-05-10)
8. ✅ **Atlas: format selected text** — wrapping snippets wrap selection via `registerWrap` coordinator closure
9. ✅ **macOS sidebar** — `columnVisibility: .all` pins sidebar open by default
10. ✅ **macOS font sizes** — `.dynamicTypeSize(.xLarge)` on preview; 15pt monospaced on editor
11. ✅ **macOS editor bottom cut off** — `contentInsets` bottom 44pt on NSScrollView

## Phase 3 — Remaining

1. **Onboarding view** — first-launch explanation of iCloud access and folder picker
2. **Auto-save robustness** — `NSFileVersion` conflict handling
3. **App icon dark/tinted variants** — iOS 18+ dark and tinted AppIcon variants

---

## Open bugs

*(none)*

---

## Fixed (last 30 days)

- **Icon white border** — outer white flood-filled with green; full-bleed to all edges. Fixed 2026-05-10.
- **Editor font size too small on iOS** — Highlightr theme overrides `textView.font`; fixed by `theme?.setCodeFont` at 17pt. Fixed 2026-05-10.
- **iOS archive: missing import** — `iOSRootView.swift` missing `import UniformTypeIdentifiers`. Fixed 2026-05-10.
- **CloudScanner Swift 6 actor error** — all scanner methods marked `@MainActor`, dropped `Task.detached`. Fixed 2026-05-10.

---

## Notes

- Reset folder picker: `defaults delete Vera rootFolderBookmark`
