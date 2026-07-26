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

### E. iPad — highest value

Four of the six commits touch the code `IPAD_FONT_SIZE_HANG.md` implicates.

- [ ] **iPad**: `RepoStatusCard.tsx` in **Preview**, tap A/A repeatedly → no hang, no CPU spin
- [ ] **iPad**: same in **Edit** mode
- [ ] If it still hangs, that doc is still accurate and `CHANGELOG.md:12` is still wrong

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
