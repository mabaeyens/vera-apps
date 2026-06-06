# Vera Test Plan

## Release 1.0.36 (build 36) — 2026-06-06

### macOS folder picker fix
- [ ] macOS: Cmd+O → NSOpenPanel opens → navigate to a folder → single-click it → **"Open" button is enabled** → clicking it loads the folder tree in the sidebar
- [ ] macOS: Cmd+O → select a `.md` file directly → still opens correctly (no regression)

### Sidebar: Open Files section
- [ ] Open a folder → open 2–3 files from the tree → **"Open Files" section appears at the top of the sidebar** listing all open files
- [ ] The active file has an **accent-color dot** on its left; inactive files have a transparent dot
- [ ] Click a non-active file in "Open Files" → that file becomes active (no duplicate tab created)
- [ ] macOS: hover over a file in "Open Files" → **× button appears** on the right → click it → tab closes, entry removed from "Open Files"
- [ ] iOS: swipe left on a file in "Open Files" → **"Close" destructive action** appears → swipe to close
- [ ] Click the "Open Files" section header → **section collapses** (list hides); click again → expands
- [ ] Relaunch the app → collapsed/expanded state of "Open Files" is remembered
- [ ] Open a file from **outside** the root folder (standalone) → it appears in "Open Files", **not** as a separate "Standalone" section in the folder tree
- [ ] With no files open, "Open Files" section is **hidden** entirely
- [ ] With no folder open but a file open (standalone), sidebar shows "Open Files" only, no folder section

### Regression: folder tree
- [ ] Folder tree still expands/collapses subfolders correctly
- [ ] Clicking a file in the folder tree still opens it in a new tab
- [ ] Hover-delete on macOS file rows in the folder tree still works
- [ ] iOS swipe-to-delete on folder tree rows still works

---

## Release 1.0.35 (build 35) — 2026-05-24

### Tabs
- [x] Tap/click multiple files in the sidebar → each opens in a new tab (not replacing the current one)
- [x] Open enough tabs to overflow the tab bar → trailing gradient fade hint appears on the right
- [x] Scroll the tab bar left/right to reach overflow tabs
- [x] Click the × on a tab → that tab closes, others remain
- [x] Click chevron.compact.up → tab bar hides; show it again from the hide/show control
- [x] Active tab has: 15pt semibold font, accent-color bottom bar, subtle fill

### iPad tab bar sizing
- [x] iPad: tab bar height is ~52pt (taller than iPhone's 40pt)
- [x] iPad: + button and hide button icons are .callout size, easy to tap
- [x] iPad: × close button on each tab is larger (20×20pt vs iPhone's 14×14pt)
- [x] iPhone: tab bar remains compact at 40pt (no regression)

### Preview mode (markdown rendering)
- [x] Open a file with a fenced code block → block renders with syntax highlighting, Copy button works
- [x] Open a file with a GFM table → table renders with column borders, no text clipping on wide cells
- [x] Open a file with a horizontal rule `---` → rule spans the full width without overflow
- [x] Text in preview is selectable; right-click/long-press copy works

### File opening / folder picker
- [x] macOS: open folder picker → NSOpenPanel opens correctly, selected folder loads in sidebar
- [x] iOS/iPad: tap "Open…" in the menu → file picker appears, accepts both folders and .md files
- [x] iOS/iPad: pick a folder → folder tree loads in sidebar, picker does NOT reappear
- [x] iOS/iPad: pick a .md file → file opens in a new tab
- [x] iOS/iPad: with standalone files already open, pick a new folder → standalones stay, new folder tree appears with section header
- [x] macOS: folder display in sidebar shows correctly (no display regression)
- [x] Font size setting applies in preview mode

### Sidebar
- [x] iOS/iPad: root folder name appears as a section header above the file tree
- [x] iOS/iPad: section header updates when a different folder is opened
- [x] macOS: section header still shows (no regression)

### New File
- [x] iOS/iPad: "New File" is enabled when a root folder is set
- [x] iOS/iPad: "New File" is only greyed out when truly no context exists (no root, no standalone files)

### Syntax-highlighted preview
- [x] Cold launch → first file opened renders syntax highlighting without crash
- [x] Switch between light/dark mode → code block colors update correctly

### New-file edit mode
- [x] Create a new file → drops into edit mode immediately (not preview)

### Linter / formatting
- [x] Linter auto-fix applies without error

### Stability
- [x] Open a file that was previously closed → opens cleanly
- [x] Reopen app after backgrounding → no crash
