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
