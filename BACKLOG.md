# Vera — Backlog

## Phase status

- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** ✅ All items complete
- **Phase 4** ✅ All items complete — pending TestFlight test pass (build 7)

---

## Phase 4 — Done

1. ✅ **macOS sidebar persistence** — `@AppStorage("sidebar.visible")` + `.navigationSplitViewStyle(.balanced)`; user's hide/show choice survives relaunches
2. ✅ **Atlas in context menu** — iOS: `editMenuForTextIn` delegate; macOS: `textView(_:menu:for:at:)`. "Format…" opens Atlas, both platforms
3. ✅ **Remove Formatting in context menu** — "Remove Formatting" appears when text is selected; strips inline (`**`, `*`, `` ` ``, `~~`, links) and block (`#`, `>`, `- `, `1.`) markdown via `String.strippingMarkdown()`
4. ✅ **New file button** — `square.and.pencil` toolbar button on macOS sidebar and iOS nav bar; `NewFileSheet` with filename field + location picker; auto-opens created file
5. ✅ **Offline banner** — `ConnectivityMonitor` (`NWPathMonitor`) injected via `.environment`; slim banner in sidebar when offline; cloud-file download button disabled/shows `icloud.slash` when offline

## Phase 4 — Remaining

*(none — all items complete)*

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
