# Vera Test Plan

Manual release checklist. Each release section lists the specific features introduced in that build plus a regression block. Check items on device before running `/vera-ship`.

---

## Unreleased

### Browse, view, and highlight any text file; render images; inert binaries
- [ ] Open a local folder or GitHub repo containing non-md files (`.py`, `.swift`, `.lock`, `.toml`, `.sh`, `.yml`, `.entitlements`, `.json`, `.css`, etc.) → all now appear in the sidebar tree (previously only `.md`/`.txt`/`.json`/`.yaml` were visible)
- [ ] Tap a `.py`/`.swift`/other source file → opens read-only with correct syntax highlighting for that language (not Markdown coloring)
- [ ] Tap a `.entitlements` or `.plist` file → opens read-only with XML highlighting
- [ ] Tap a file with an extension Vera doesn't recognize (e.g. a random dotfile) → still opens as plain, unhighlighted monospace text (doesn't error)
- [ ] Open one of the newly-visible files → **no Edit button** appears anywhere in the toolbar (confirms it's read-only, no accidental edit path)
- [ ] Tap a `.png`/`.jpg`/`.svg` file in a local folder → renders as an image (fit-to-width, scrollable)
- [ ] Tap a `.png`/`.jpg` in a **private** GitHub repo → renders correctly (confirms the authenticated Contents-API path works, not just public raw URLs)
- [ ] Add a binary file (`.dmg`, `.zip`, `.pdf`, etc.) to a test folder → it appears in the tree with a distinct/dimmed icon, but tapping or clicking it **does nothing** (no crash, no blank screen, no error)
- [ ] Drag-and-drop or Cmd+O a genuinely binary file directly → shows the "not a supported document type" alert (different from the silent tree-tap behavior, since this is an explicit user action)
- [ ] Open a deliberately malformed `.json` file → a lint warning banner appears ("Invalid JSON…") with **no Auto-fix button** (read-only/non-editable formats never get one)
- [ ] Open a `.yaml` file with a tab-indented line → flagged as a lint warning
- [ ] Open any read-only text file with trailing whitespace or no final newline → flagged as lint warnings
- [ ] Confirm the 4 original editable formats (`.md`/`.txt`/`.json`/`.yaml`) are completely unaffected — still fully editable, committable, and Markdown's own linter/Auto-fix behave exactly as before

### Format-aware live editor highlighting + per-file "no highlighter in Focus Mode"
- [ ] Open a `.json` file and edit it → now shows correct **JSON** syntax highlighting while typing (previously it was incorrectly highlighted as Markdown)
- [ ] Open a `.yaml` file and edit it → now shows correct **YAML** highlighting while typing
- [ ] Open a `.txt` file and edit it → now renders as plain, unhighlighted monospace text while typing (previously incorrectly Markdown-highlighted)
- [ ] Open a `.md` file and edit it → Markdown highlighting is unchanged (no regression)
- [ ] Enable Focus Mode while editing any file → highlighting stays on by default
- [ ] With Focus Mode on, tap the new highlighter toggle in the toolbar → highlighting turns off live for that file; tap again to confirm it returns
- [ ] Exit Focus Mode → highlighting returns regardless of the per-file toggle state
- [ ] Close and reopen the same file with Focus Mode on → the "highlighting off" choice persists for that file
- [ ] Open a *different* file with Focus Mode on → highlighting is on by default (the per-file choice doesn't leak across files)

### GitHub sidebar file-format visibility + full-editor routing
- [ ] Sidebar tree for a connected GitHub repo shows non-`.md` supported files too (not just Markdown)
- [ ] Connect a **brand-new** GitHub repo via "Open from GitHub…" → the sheet dismisses right after connecting and the repo appears in the sidebar, ready to expand and pick a file from the tree
- [ ] Tap a file from the sidebar tree, and tap a file from within the GitHub browser sheet (e.g. via search on an already-saved repo) → both open in the **same full editor** (tab bar visible, no cramped narrow-dialog push)
- [ ] Revisit an already-saved repo via "Open from GitHub…" → branch switching and (with ≥2 dirty drafts) "Commit N Files" are still reachable
- [ ] iOS: use the "Open folder or file" picker to select a standalone `.txt`, `.json`, or `.yaml` file directly (not via a scanned folder) → selectable and opens correctly

### Regression
- [ ] iCloud: open/edit/autosave/tabs/pinning unchanged
- [ ] GitHub: single-file commit/PR, multi-file commit, branch switching, conflict recovery all still work unchanged
- [ ] VoiceOver reads accessibility labels on the new toolbar buttons (highlighter toggle, image viewer)

---

## Release 1.2.0 (build 1) — 2026-07-06

### GitHub sign-in (Device Flow)
- [ ] Sidebar → Add Repository… → "Open from GitHub" shows a GitHub OAuth sign-in option alongside the PAT field
- [ ] Tapping sign-in requests a device code and shows it with the `github.com/login/device` URL
- [ ] Approving the code on github.com completes sign-in in Vera automatically (no copy/paste back into the app)
- [ ] First-time sign-in on an account that hasn't installed the Vera GitHub App: connecting a repo surfaces a clear error, and installing the app via `github.com/settings/apps/<slug>/installations` resolves it
- [ ] The PAT field still works as a fallback path

### Repo search (Feature 6)
- [ ] Typing in the repo file list search bar filters by filename instantly, no network call
- [ ] "Search in content" mode returns Code Search API matches with a highlighted fragment
- [ ] Rapid typing debounces content search (≤1 call per 800ms pause); hitting the rate limit shows a clear message

### Conflict recovery (Feature 3)
- [ ] Commit a file that changed remotely since it was opened → a "The file changed on GitHub" sheet appears (not a raw error)
- [ ] "View Diff" shows the remote version vs. local edits
- [ ] "Overwrite" re-fetches the current SHA and commits successfully

### Branch switching (Feature 5)
- [ ] Repo file list toolbar shows the current branch; switching branches re-fetches the file tree
- [ ] Files already open in tabs keep their original branch after switching the browser's branch

### Branch picker in commit sheet (Feature 2)
- [ ] Commit sheet shows a branch picker defaulting to the file's branch
- [ ] Selecting a different branch and committing writes to that branch
- [ ] In Pull Request mode, the picker sets the PR's base branch

### Multi-file commits (Feature 4)
- [ ] Editing 2+ GitHub files shows a "Commit N files" option in the repo sidebar tab
- [ ] The multi-file commit sheet lists all dirty files pre-ticked with a single message field
- [ ] Committing multiple files lands as one atomic commit (Git Data API), visible on GitHub as a single commit touching all files
- [ ] Multi-file Pull Request path creates one branch with one commit containing all files

### Regression
- [ ] iCloud: open/edit/autosave/tabs/pinning unchanged
- [ ] Single-file commit/PR from Release 1.1.0 still works unchanged

---

## Release 1.1.0 (build 1) — 2026-06-21

### GitHub (browse, edit, commit)
- [ ] Add Repository… → enter owner/repo + a fine-grained token (Contents: Read/Write) → repo appears under the "GitHub" sidebar section
- [ ] Expand a repo → its Markdown tree loads (folders + .md files); drilling into subfolders works
- [ ] Tap a repo file → opens in a **tab** alongside local files, with the full editor (highlighting, formatting bar, snippets, Focus)
- [ ] Edit a GitHub file → **Commit** (direct) succeeds; file refreshes in place
- [ ] Edit a GitHub file → **open Pull Request** succeeds; the GitHub link works
- [ ] When a repo file moved on since last opened → **What Changed** shows a native diff
- [ ] Token is device-local (Keychain): a second device on the same iCloud sees the repo in the list but must add its own token (expanding without a token opens the connect sheet)
- [ ] Repo list syncs across devices via iCloud (add on one device → appears on another)

### Sidebar
- [ ] Local folder collapses/expands via a **leading-chevron** disclosure row (matches GitHub repos); state persists across launches
- [ ] iPad: expanding a nested subfolder shows its files (deep nesting works)
- [ ] `.md` rows show the **Markdown mark** icon; the active file is accent-tinted
- [ ] macOS: hovering a file row shows **no** trash; right-click → Delete works and confirms

### Focus Mode
- [ ] macOS: toggle Focus → tab bar + lint panel hidden, sidebar collapses; toggle off restores all three
- [ ] iPhone: Focus hides the keyboard formatting bar

### Icon Guide
- [ ] Opens from the ••• overflow menu on iPhone, iPad and Mac
- [ ] Listed icons match the platform (Refresh / Copy All Text appear on Mac only)

### About
- [ ] Credits list Highlightr, swift-markdown-ui and the Markdown mark (dcurtis)

### Regression
- [ ] iCloud: open/edit/**autosave**/tabs/pinning unchanged (primary regression check)
- [ ] Open folder, open files, switch/close tabs, create new file — all still work
- [ ] VoiceOver reads accessibility labels on toolbar/sidebar icon buttons

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

