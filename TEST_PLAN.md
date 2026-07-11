# Vera Test Plan

Manual release checklist. Each release section lists the specific features introduced in that build plus a regression block. Check items on device before running `/vera-ship`.

---

## Unreleased

Everything from the prior 1.3.1 passes has been verified and passed, including past
releases. Remaining: the compile-error fix, and a new iPad-only hang found during that
retest. Per the iPad-is-a-distinct-target correction below, device rows are now split
explicitly wherever a feature has a real iPhone/iPad code-path difference — don't lump
"iOS" together for anything touching edit-mode toolbars.

### HighlightrEngine actor isolation (compile error, blocked all testing)
- [ ] Build the project (iOS + macOS) → compiles cleanly, no more "Call to main actor-isolated global function 'applyMonoFont(to:size:)' in a synchronous actor-isolated context"
- [ ] Open any file with syntax highlighting (code file, or a Markdown fenced code block) on iPhone, iPad, and Mac → highlighting still renders correctly (regression check — confirms the `nonisolated` fix didn't break font application)

### Font-size change while editing a code file froze the app (iPad-only regression)
- [ ] **iPad**: open `RepoStatusCard.tsx` (or any sizeable code file), tap Edit, tap the smaller/larger text buttons in the bottom formatting bar repeatedly → no freeze, resizes instantly
- [ ] **iPhone**: same steps (font-size buttons aren't in the compact-width keyboard accessory bar today, so this is mainly a regression guard, not a new repro path)
- [ ] **Mac**: same steps via the toolbar font-size control while editing a code file → no freeze (was already fine, confirm it stays fine)
- [ ] On all 3: switching theme (light/dark) and switching to a different file's language while editing still re-highlights correctly (confirms the fix didn't break the cases that *do* need a full re-tokenize)

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

