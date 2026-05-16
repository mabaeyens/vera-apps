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

1. **edit in preview mode**, keeping the format of the edited block
2. **animated** V icon
3. delays when selecting other folders - no activity signal
4. folder name not updated after switching folders
5. add contextual format option higher
6. top of keyboard formatting menu like the iOS Notes app?
7. keep downloaded files downloaded across sessions, unless cloud is more updated
8. markdown references rendering issues: blockquote and superindex/footnote

---

## Pending release (built, not yet shipped)

- **Larger editor font** — iOS bumped from 17pt → 20pt, macOS from 15pt → 17pt. `HighlightingTextView.swift` (both `makeView` and `updateView` for each platform).
- **Folder name in title bar** — Navigation title now shows `rootURL.lastPathComponent` instead of hardcoded "Vera". iOS: `iOSRootView.swift`. macOS: `MacRootView.swift` sidebar column.
- **macOS bottom scroll clipping** — Added `.padding(.bottom, 32)` to Markdown content in `ViewingModeView.swift` so the last line isn't clipped by the window edge.
- **macOS sidebar never autocollapse** — Replaced `visibilityBinding`/`sidebarPinned` with `@State userHidSidebar` + `onChange(of: columnVisibility)` guard that reverts any system-driven collapse. Toolbar button is the only way to hide sidebar. `MacRootView.swift`.
- **iOS portrait navigation fixed** — Switched iOS `List` to `List(selection: $selectedURL)` with `.tag(url)` on file rows. `NavigationSplitView` now pushes the detail natively on iPhone instead of relying on `columnVisibility = .detailOnly` which doesn't work in compact mode. `FileTreeView.swift` + `iOSRootView.swift`.
- **Cloud file download on iOS** — When a cloud file is selected, download is triggered and selection is cleared (navigates back). `iOSRootView.swift` `onChange(of: selectedURL)`.

### Shipped in build 12
- Portrait mode navigation (partial fix — see above for full fix)
- Background freeze fix (`NSFileCoordinator` off main thread, `DocumentStore.swift`)
- Foreground refresh (`scenePhase` observer, `iOSRootView.swift`)

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
