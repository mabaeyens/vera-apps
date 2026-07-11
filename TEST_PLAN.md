# Vera Test Plan

Manual release checklist. Each release section lists the specific features introduced in that build plus a regression block. Check items on device before running `/vera-ship`.

---

## Unreleased

Full rewrite for 1.3.1 — the previous "Unreleased" section predated the entire 1.3.0
surface and this release's "edit any file type" change, so it didn't check for any of
this. Historical release sections below are unaffected.

### Edit any file type, not just Markdown/Text/JSON/YAML (1.3.1 headline change)
- [ ] Open a local `.swift`/`.py`/`.tsx` (or any other previously read-only source) file → an **Edit button now appears** in the toolbar
- [ ] Edit it and confirm autosave works exactly like Markdown (check the save indicator, relaunch and confirm the edit persisted)
- [ ] Open the same kind of file from a **connected GitHub repo**, edit it, and **Commit** (direct commit) → succeeds
- [ ] Same file, **open Pull Request** instead → succeeds, GitHub link works
- [ ] While editing a `.swift` file: confirm **no bold/italic/heading/list/quote/paintbrush formatting bar** appears (iPad bottom bar and iPhone keyboard accessory) — syntax highlighting still applies, just no Markdown-insertion buttons
- [ ] On iPad, while editing a `.swift` file: confirm the **font-size (A/A) buttons are still present** in the bottom bar even though the Markdown buttons are hidden
- [ ] Open a `.md` file and edit it → formatting bar (bold/italic/etc.), Auto-fix button, and paintbrush "Format & Snippets" button are **all still present**, unchanged
- [ ] Open a `.json` or `.yaml` file and edit it → editable, autosaves, **no** formatting bar, **no** Auto-fix button (JSON/YAML never had one), JSON/YAML-specific lint still runs
- [ ] Open a `.txt` file and edit it → editable, no formatting bar, unchanged from before
- [ ] Open a `.png`/`.jpg` or a binary file (`.dmg`, `.zip`, etc.) → still **no Edit button anywhere** (images/binaries stay non-editable)
- [ ] New File… picker still shows only Markdown/Text/JSON/YAML (unchanged) — but an **existing** `.swift`/`.py`/etc. file opens straight into a working editor
- [ ] Multi-file commit sheet: dirty a `.md` file and a `.swift` file together → both appear and commit atomically in one commit, same as any other multi-file commit

### GitHub 404 diagnostics + stale-token detection (v1.3.0)
- [ ] Connect a repo using an old/stale token (not signed in via Device Flow) → shows the specific "not signed in through Vera's GitHub App" message, not the generic "not found"
- [ ] Tap "Not you? Sign in with a different account" → clears the token and reopens "Sign in with GitHub"
- [ ] Fresh Device Flow sign-in, then connect a private repo the App has full access to (e.g. `mabaeyens/uigen`) → connects successfully
- [ ] Error text in the connect sheet is selectable/copyable
- [ ] "Open from GitHub" sheet shows only **one** Owner/Repository field pair after signing in (no duplicate fields)

### Pull-to-refresh the sidebar (staged for 1.3.1)
- [ ] iOS/iPadOS: swipe down on the file tree sidebar → shows the refresh spinner
- [ ] Add/push a new file to a connected repo from another device or github.com, then pull to refresh in Vera → the new file appears **without relaunching the app**
- [ ] Pull to refresh also rescans the local/iCloud folder tree (add a file locally via Finder/Files, pull to refresh, confirm it appears)

### macOS folder click (regression check)
- [ ] Click anywhere on a folder row (not just the chevron) → **iOS/iPadOS**: expands/collapses. **macOS**: clicking the chevron still expands/collapses correctly (macOS intentionally does NOT expand on a row-body click — confirm this still works via the chevron after the emergency revert)

### macOS line-number gutter (needs real device confirmation — 2 prior attempts failed)
- [ ] Open a long code file (30+ lines) on macOS, in edit mode with line numbers on
- [ ] Scroll down slowly, then quickly — line numbers stay correctly aligned with their lines at every scroll depth, no drifting or disappearing
- [ ] Scroll back up — same check in reverse

### Font size in syntax-highlighted code (v1.3.0 fix)
- [ ] View or edit a `.swift` file, tap the larger/smaller text buttons → text size actually changes (previously silently did nothing)
- [ ] Open a Markdown file with a fenced code block, change font size → the code block's text resizes too

### Carried over from 1.3.0 — still unconfirmed on device
- [ ] Pinch to zoom an opened image (local and GitHub) on iOS → re-fits and zooms correctly, no longer stuck at native pixel size
- [ ] `.tsx` and `.cjs` files → correct TypeScript/JavaScript syntax highlighting

### Regression
- [ ] iCloud: open/edit/autosave/tabs/pinning unchanged
- [ ] GitHub: single-file commit/PR, multi-file commit, branch switching, conflict recovery all still work unchanged
- [ ] Binary file in the tree → tapping/clicking still does nothing (no crash, no accidental open)
- [ ] VoiceOver reads accessibility labels on toolbar buttons

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

