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

### Line-number gutter performance + base font size 15 (2026-07-26)

The gutter used to derive each line number by copying the whole document prefix and
splitting it, once per visible line, inside `draw(_:)`. Measured at 140 ms per frame while
scrolling a 5000-line file (roughly 7 fps); now 0.0006 ms per frame, with a 1.3 ms index
rebuild per text change. The new line index was fuzz-checked against the old algorithm over
69,555 cases (including CRLF, unicode, emoji, empty and newline-only documents) with zero
divergence, so line numbers should be identical, not merely plausible.

Also in this change: base font size is now 15 everywhere (`Theme.Typography.codeSize` and
`Defaults.FontSize.default` agree, matching DESIGN.md; was 15 vs 18), and the macOS gutter
now tracks the font-size control at all, which it never did before.

- [ ] **Mac / iPhone / iPad**: open a large code file (5000+ lines) with line numbers on, scroll fast to the bottom → smooth, no stutter, numbers keep up with the text
- [ ] **All 3**: line numbers are *correct* at the very bottom of a large file (not just present) — cross-check the last line number against the file's real line count
- [ ] **All 3**: type in the middle of a large file, including pressing Return and deleting a line → numbers renumber immediately and stay correct
- [ ] **All 3**: paste a large block, and undo it → numbers stay correct
- [ ] **All 3**: a file with a very long soft-wrapped line → wrapped continuation rows get **no** number, only real line starts do
- [ ] **Mac**: tap the A/A font-size control while editing → the **gutter digits resize too** (this is new; previously the macOS gutter was pinned at 11pt and ignored the control)
- [ ] **Mac**: size up to the maximum (32) on a file with 4- and 5-digit line numbers → digits do not clip, gutter widens
- [ ] **All 3**: toggle line numbers off and on → gutter reappears correctly
- [ ] **All 3**: fresh install (or reset) → default text size is now 15, and editor and preview look the same size as each other
- [ ] **iPad**: re-run the `RepoStatusCard.tsx` A/A checks below — this change touches the same file as the open hang in `IPAD_FONT_SIZE_HANG.md`

### iCloud downloads are explained and cancellable (2026-07-26)

Opening a file not yet downloaded from iCloud used to show a bare spinner for up to 15
seconds and then leave the document blank with no explanation. It also only polled, without
ever requesting the download unless the file had been tapped in the sidebar.

Needs a device with "Optimise Mac Storage" / iCloud offloading so files show the cloud
badge. Evicting a file with `brctl evict <path>` is the quickest way to set this up.

- [ ] **All 3**: open an evicted (cloud-badge) text file → shows "Downloading from iCloud" with the file name, not a bare spinner; the file opens on its own once it arrives
- [ ] **All 3**: open an evicted file with Wi-Fi off → after the wait, shows an explanation and a **Try Again** button; tapping it retries
- [ ] **All 3**: tap **Cancel** during the download → returns to an explanatory state immediately, does not hang
- [ ] **All 3**: same three checks for an evicted **image** file (`ImageViewerView` has its own copy of this path)
- [ ] **All 3**: open a file that is *not* valid UTF-8 → shows "Couldn't Open File" rather than an empty editor. **Important:** confirm the original file is unchanged on disk afterwards, since an empty editor plus autosave would previously have overwritten it
- [ ] **All 3**: regression — a normal local file still opens instantly with no flash of either new state

### Preview main-thread work moved off (2026-07-26)

Markdown segment parsing now runs on a detached task, per-line splitting of highlighted
code happens inside `HighlightrEngine` instead of after the `await` (which resumed on the
main actor), `HighlightedCodeView` does one pass instead of three plus a full-document
hash per body evaluation, word/character counts are memoised, and table column widths are
computed once in `init`. Syntax highlighting is now capped at 1 MB.

Mostly regression checks: the visible behaviour should be unchanged except where noted.

- [ ] **All 3**: open a large Markdown file with fenced code blocks and tables → renders correctly, code is highlighted, tables lay out as before
- [ ] **All 3**: scroll a long syntax-highlighted file fast → smooth, and the highlighting does not flicker or disappear
- [ ] **All 3**: switch light/dark while a code file is open in Preview → re-highlights correctly in the new theme
- [ ] **All 3**: change text size (A/A) in Preview on a code file → resizes, stays highlighted
- [ ] **All 3**: a Markdown file whose tables and code blocks are unchanged still shows the **same column widths** as before (colWidths moved into `init`; a regression here would show as wrong/clipped columns)
- [ ] **All 3**: word and character counts in the editing toolbar update as you type and are **correct** (they are cached now, so a stale count is the failure mode to watch for) — including after undo, paste, and Auto-fix
- [ ] **All 3**: open a file **over 1 MB** with a code extension → opens promptly, shows plain monospaced text plus an "over 1 MB" note, and does **not** hang
- [ ] **All 3**: open a file just under 1 MB → still fully highlighted
- [ ] **iPad**: re-run the `RepoStatusCard.tsx` preview A/A checks — several of these changes are in the code path `IPAD_FONT_SIZE_HANG.md` implicates, so this is the highest-value check in this block

### One typography scale, one Dynamic Type ramp (2026-07-26)

Vera's hand-written `monoScale` is gone. Every surface now resolves its size through
`Theme.Typography` on Apple's `.body` ramp, which is the ramp MarkdownUI was already using
internally. Tables lost a hardcoded `* 0.8` and gained Dynamic Type.

The failure mode to watch for is **double scaling**: MarkdownUI applies `ScaledMetric`
itself and is deliberately the only caller handed an *unscaled* size. If prose balloons at
large accessibility sizes while code stays sane, that is the bug.

- [ ] **All 3**: open a Markdown file with prose, a table and a fenced code block. Toggle Edit / Done repeatedly → **no perceptible size change** in any of the three
- [ ] **iPhone + iPad**: set Larger Text to maximum (`.accessibility5`) in Settings, reopen the same file → prose, table cells, inline code and code blocks all grow **together**, and the editor still matches the preview
- [ ] **iPhone + iPad**: at `.accessibility5`, confirm prose is not absurdly larger than code — that would be the double-scaling regression
- [ ] **iPhone + iPad**: walk the middle sizes too (xSmall, large, xxxLarge) → everything tracks proportionally
- [ ] **All 3**: **table text is now the same size as prose**, not visibly smaller (this is the most visible intended change)
- [ ] **All 3**: wide table still lays out with sensible column widths and scrolls horizontally where needed (column widths are derived from cached character counts now)
- [ ] **All 3**: a plain `.txt` file with no syntax highlighting responds to Larger Text (it previously ignored it entirely)
- [ ] **Mac**: no Dynamic Type on macOS, so only the A/A control should move text; confirm it moves editor, preview, tables, code blocks and gutter together

### Open documents stay loaded (2026-07-26)

`EditorViewModel` now lives on the tab instead of inside `DocumentView`, so switching tabs
no longer destroys the editor and re-reads the file. **This touches autosave, so the
data-loss checks below matter more than the speed ones.**

- [ ] **All 3**: open 3+ files, switch between them repeatedly → **instant**, no spinner, no flash
- [ ] **All 3**: scroll to the middle of a long file, switch away and back → **same scroll position**
- [ ] **All 3**: switch a file to Edit mode, switch tabs away and back → **still in Edit mode**
- [ ] **All 3**: type in file A, immediately switch to file B (inside the 500 ms autosave debounce), switch back → **the edit is there**, and the file on disk contains it
- [ ] **All 3**: type in a file and immediately **close its tab** → edit is written to disk (`closeTab` flushes before releasing the editor)
- [ ] **iPhone/iPad**: type in a file and immediately background the app → edit is written (the `onDisappear` flush no longer covers this; the scene-phase flush does)
- [ ] **Mac**: same, by switching to another app
- [ ] **All 3**: edit a file **outside Vera** (another editor, or `git checkout`) while its tab is open but inactive, then switch back to that tab → Vera picks up the new content
- [ ] **All 3**: same, but with **unsaved edits** in Vera → Vera does **not** silently discard your edits
- [ ] **All 3**: open **more than 8** files, then return to the first one → it reloads correctly (LRU eviction dropped its text)
- [ ] **All 3**: open more than 8 files with an **unsaved edit** in the oldest, return to it → **the edit is still there** (eviction must refuse to drop unsaved work)
- [ ] **GitHub**: open a GitHub file, make an uncommitted edit, open 8+ other files, return → uncommitted edit intact, still marked uncommitted
- [ ] **All 3**: delete an open file from the sidebar → its tab closes cleanly, no crash
- [ ] **All 3**: memory check — open ~10 large files, confirm memory does not climb without bound

Per the iPad-is-a-distinct-target correction: iPhone/iPad/Mac are checked as 3 separate
targets below wherever a feature has a real per-device code-path difference — don't lump
"iOS" together for anything touching edit-mode toolbars or layout timing.

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
