# Vera Test Plan

Manual release checklist. Update this section with the specific features introduced in
the current unreleased build plus a regression block. Check items on device before
running `/vera-ship`. Cleared of historical per-release sections going back to 1.0.36 —
git history/CHANGELOG.md is the record of what shipped when; this file only tracks what
still needs on-device verification for the next release.

---

## Unreleased

Everything from the prior 1.3.1 passes has been verified and passed. Remaining: the
compile-error fix, and three related iPad-only issues found during that retest (font-size
hang while editing code, the line-number gutter not appearing until scrolled, and a
second font-size-in-preview hang/CPU spin).

---

## 2026-07-26 rework — check on device

Six commits, build-verified only. Nothing below has run on hardware.
Check on **iPhone, iPad and Mac** — they are three targets, not "iOS + macOS".

### A. Data loss (do these first)

Autosave paths moved when editors started outliving views. If any of these fail, stop.

- [ ] Type in a file, immediately switch tabs (inside the 500 ms debounce), switch back → edit present, and on disk
- [ ] Type, immediately **close the tab** → edit on disk
- [ ] Type, immediately **background the app** → edit on disk
- [ ] Open 9+ files, return to the first → reloads correctly
- [ ] Same, but with an unsaved edit in the oldest → **edit still there** (eviction must refuse to drop unsaved work)
- [ ] GitHub file with an uncommitted edit, open 8+ others, return → edit intact, still marked uncommitted
- [ ] Open a non-UTF8 file → "Couldn't Open File", and the original is **unchanged on disk**

### B. Speed and stability

- [ ] Switch between open files → instant, no spinner, no flash
- [ ] Switch away and back → scroll position and Edit/Preview mode both survive
- [ ] Scroll a 5000-line file fast with line numbers on → smooth
- [ ] Line numbers **correct** at the bottom of a large file (not just present)
- [ ] Type / Return / delete a line mid-file → renumbers correctly
- [ ] Long soft-wrapped line → continuation rows get no number
- [ ] Open a file **over 1 MB** → opens promptly, plain text, "over 1 MB" note, no hang

### C. Typography

- [ ] Toggle Edit / Done on a file with prose + table + code block → **no size jump** in any of the three
- [ ] Tables are now the **same size as prose**, not smaller (most visible intended change)
- [ ] iPhone/iPad at max Larger Text → prose, tables, code and editor grow **together**; prose not wildly larger than code (that would be double-scaling)
- [ ] Plain `.txt` responds to Larger Text (it previously ignored it)
- [ ] **Mac**: A/A moves editor, preview, tables, code **and the gutter** (gutter is new; it was pinned at 11 pt)
- [ ] **Mac**: gutter is now ~52 pt wide, was 36 pt — deliberate, but check it doesn't look heavy
- [ ] Fresh install → default text size 15

### D. iCloud

Needs an evicted file: `brctl evict <path>`.

- [ ] Open an evicted file → "Downloading from iCloud", not a bare spinner; opens when it arrives
- [ ] Same with Wi-Fi off → explanation + **Try Again** button that works
- [ ] Tap **Cancel** mid-download → returns to an explanatory state (may lag ~1 s, known)
- [ ] Repeat for an evicted **image**
- [ ] Switch tabs *during* a download, come back → retries cleanly, no stale error

### E. iPad — font-size hang (**passed 2026-07-26**)

Four of the six commits touch the code `IPAD_FONT_SIZE_HANG.md` implicates. Confirmed on
a physical iPad: the hang is gone. Keep this section as a permanent regression check — it
has come back before, and three "fixes" for it were wrong.

- [x] **iPad**: `RepoStatusCard.tsx` in **Preview**, tap A/A repeatedly → no hang, no CPU spin
- [ ] **iPad**: same in **Edit** mode

### G. Sidebar is now the only place open documents live

The tab bar is deleted. **Judgement call for you:** on iPhone there's no persistent
sidebar, so back-to-tree is now the only way to switch documents. Standard iOS, but a real
reduction — if it feels wrong, say so and I'll put a switcher back on iPhone only.

- [ ] No tab bar anywhere; overflow menu no longer offers Hide/Show Tab Bar
- [ ] Sidebar "Open Files": tap activates, close button is **always visible** (no hover needed on Mac)
- [ ] Right-click / long-press a row → Close, Close Others, and Reveal in Finder (Mac)
- [ ] **Close the last remaining document** → it actually closes and shows the empty state (this silently did nothing before)
- [ ] Close Others leaves exactly one tab, and the right one stays active
- [ ] Type in a local file → a quiet dot appears briefly while saving, then clears
- [ ] GitHub file with uncommitted changes → accent dot persists; closing it **warns** first
- [ ] Closing a local file does **not** warn (it autosaves), and the edit is on disk
- [ ] **iPhone**: does switching documents still feel workable without the tab bar?

### H. Menu bar and keyboard shortcuts (new)

The app previously declared no menus at all and had three keyboard shortcuts total.
On **iPad, attach a hardware keyboard** — it gets the same shortcuts.

- [ ] **Mac**: menu bar shows File / Edit / Format / View / Navigate / Help
- [ ] ⌘N new file · ⌘O open file · ⇧⌘O open folder · ⌘W close · ⌘S save
- [ ] **⌘S on a file mid-edit writes immediately** (must never be a no-op, even though Vera autosaves)
- [ ] ⌘B / ⌘I / ⇧⌘X / ⇧⌘C / ⌘K apply formatting, same result as the formatting bar
- [ ] ⌃⌘1 / ⌃⌘2 / ⌃⌘3 insert headings (⌃⌘, *not* ⌘ — ⌘1-9 switch documents)
- [ ] ⌘1…9 jump to the Nth open document; ⇧⌘] / ⇧⌘[ cycle
- [ ] ⇧⌘P toggles Edit/Preview · ⇧⌘F Focus Mode · ⌘+ / ⌘- / ⌘0 text size
- [ ] Format menu is **greyed out** on a non-Markdown file, and in Preview mode
- [ ] File > Save and Close are greyed out with no document open
- [ ] **⌘, opens Settings** (new window; preferences were buried in About before)
- [ ] Settings changes take effect immediately and match the About sheet's linter toggle
- [ ] Help > Markdown Reference and Icon Guide open their sheets
- [ ] **iPad with keyboard**: the same shortcuts work; hold ⌘ to see the shortcut HUD
- [ ] **Focus Mode with the sidebar collapsed**: ⌘1-9 and ⇧⌘] still switch documents (this is now the only way)

### I. Find and replace (new)

There was no way to search inside a document before. Uses the platform-native UI
(`NSTextFinder` / `UIFindInteraction`), not a bespoke bar.

- [ ] **Mac**: ⌘F opens the find bar in an editable document; type → matches highlight as you go
- [ ] ⌘G / ⇧⌘G cycle matches and wrap around; match count is shown
- [ ] ⌥⌘F opens replace; **Replace All works**
- [ ] **After a replace-all, syntax highlighting is still correct** (not lost or corrupted)
- [ ] After a replace-all, apply a formatting action (⌘B) → **no crash** (a stale cached range was previously an NSRangeException)
- [ ] A replace-all produces **one** save, not one per replacement — watch the save indicator
- [ ] **⌘F while in Preview** → switches to Edit and opens find (it would otherwise be dead)
- [ ] **iPad with keyboard**: ⌘F in Edit opens the native find navigator; ⌘F in Preview switches to Edit and opens it
- [ ] Find menu items are greyed out with no document open

### J. Folder search (new)

Search box at the top of the sidebar. Results replace the tree while a query is active.
Matches filenames **and** content. Needs 2+ characters.

- [ ] Type in the sidebar search → results appear, "Files" section first, then content matches grouped by file
- [ ] Results **stream in** rather than appearing all at once at the end
- [ ] Typing quickly does not stall the UI, and results don't stack up from earlier queries
- [ ] Click a **filename** result → opens that file
- [ ] Click a **content** result → opens that file and scrolls to that line
- [ ] Clear the search → the file tree comes back unchanged
- [ ] `node_modules` / `.build` / `.git` are **not** searched (try a term that only appears there)
- [ ] A term in a `.gitignore`d directory is not returned
- [ ] Search a large repo → if capped, the footer says "Showing the first 200 matches"
- [ ] With an evicted iCloud file present → footer reports it as not searched, and **does not** trigger a folder-wide download
- [ ] A file over 1 MB is reported as skipped rather than silently omitted
- [ ] Search with no folder open → nothing breaks

### F. Regressions

- [ ] Normal local file opens instantly, no flash of any new state
- [ ] Markdown with tables + code renders correctly; column widths sane; wide table scrolls
- [ ] Light/dark toggle on a code file re-highlights correctly
- [ ] Word/character counts correct as you type, and after undo, paste and Auto-fix
- [ ] Delete an open file from the sidebar → tab closes, no crash
- [ ] Edit a file outside Vera while its tab is inactive, return to it → Vera picks up the change

---

## Earlier 1.3.1 items (unverified)


### HighlightrEngine actor isolation (compile error, blocked all testing)
- [ ] Build the project (iOS + macOS) → compiles cleanly, no more "Call to main actor-isolated global function 'applyMonoFont(to:size:)' in a synchronous actor-isolated context"
- [ ] Open any file with syntax highlighting (code file, or a Markdown fenced code block) on iPhone, iPad, and Mac → highlighting still renders correctly (regression check — confirms the `nonisolated` fix didn't break font application)

### Font-size change while editing a code file froze the app
- [ ] **iPad**: open `RepoStatusCard.tsx` (or any sizeable code file), tap Edit, tap the smaller/larger text buttons in the bottom formatting bar repeatedly → no freeze, resizes instantly
- [ ] **iPhone**: same steps (font-size buttons aren't in the compact-width keyboard accessory bar today, so this is mainly a regression guard, not a new repro path)
- [ ] **Mac**: same steps via the toolbar font-size control while editing a code file → no freeze (was already fine, confirm it stays fine)
- [ ] On all 3: switching theme (light/dark) and switching to a different file's language while editing still re-highlights correctly (confirms the fix didn't break the cases that *do* need a full re-tokenize)

### Line-number gutter invisible at first on iPad
- [ ] **iPad**: open a code file, tap Edit with line numbers on → gutter numbers are visible **immediately**, no scroll needed
- [ ] **iPhone** and **Mac**: same check, regression guard (both were already fine)
- [ ] Rotate the iPad / enter and exit split view while editing → gutter height stays correct

### Font-size in Preview mode hung the app / pegged CPU on iPad (2nd tap)
- [ ] **iPad**: open `RepoStatusCard.tsx` in Preview (no Edit tap), tap the smaller/larger text buttons repeatedly, several times in a row → no freeze, no CPU spike, resizes instantly each tap
- [ ] **iPad**: same check on a Markdown file (uses `MarkdownDocumentView`, the sibling code path) → no freeze
- [ ] **iPhone** and **Mac**: same checks, regression guard (both were already fine — CPU stayed at 0% while iPad spiked to 100% with a SwiftUI "OnScrollGeometryChange Modifier tried to update multiple times per frame" fault)
- [ ] Scroll a long file in Preview on all 3 devices → scroll position still updates smoothly, and re-entering Edit mode still opens at the last-read scroll position (confirms the `readingScrollFraction` hookup wasn't silently broken by switching it from a binding to a closure)

### Regression
- [ ] iCloud: open/edit/autosave/tabs/pinning unchanged
- [ ] GitHub: single-file commit/PR, multi-file commit, branch switching, conflict recovery all still work unchanged
- [ ] Edit-any-file-type (1.3.1 headline feature): still works end to end on all 3 devices — open a non-Markdown file, Edit, commit
