# Vera Test Plan

Manual release checklist. Each release section lists the specific features introduced in that build plus a regression block. Check items on device before running `/vera-ship`.

---

## Release 1.0.37 (build 37) — 2026-06-21

### Launch: no false "Couldn't Load Files"
- [ ] macOS & iOS: cold launch with a previously-selected folder → sidebar populates directly; the "Couldn't Load Files" error does **not** flash (transient cold-iCloud scan now retries before erroring)
- [ ] Refresh / reopen still recovers if a scan genuinely fails (folder really removed → picker appears)

### Keychain bookmark migration (M2)
- [ ] Update from a build that stored the bookmark in UserDefaults → folder still loads on first launch (migrated to Keychain), no re-pick required
- [ ] Relaunch again → folder still loads (now read from Keychain)
- [ ] `defaults read Vera rootFolderBookmark` no longer returns the bookmark blob after first launch
- [ ] About → "Reset Vera…" → folder selection cleared; relaunch shows folder picker

### Privacy manifest
- [ ] `PrivacyInfo.xcprivacy` present in the built app (macOS `Contents/Resources/`, iOS app root) — verified in build 37

### Regression
- [ ] Open folder, open files, switch/close tabs, create new file — all still work
- [ ] VoiceOver reads accessibility labels on toolbar/sidebar icon buttons

---

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

