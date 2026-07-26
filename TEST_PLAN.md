# Vera Test Plan

Manual release checklist. Run the open items on device before `/vera-ship`, then move
anything that passed into the validated list. `CHANGELOG.md` and git history are the
record of what shipped when; this file only tracks what still needs a device pass.

Check on **iPhone, iPad and Mac**. They are three targets, not "iOS + macOS".

---

## Open before the next ship

### A. Data loss

The one section that has never been run. Autosave paths moved when editors started
outliving views, and a bug of exactly this shape was already caught in review. Nothing
here depends on the tab bar: it is about the 500 ms autosave debounce surviving a switch,
a close and a backgrounding. If any of these fail, stop.

- [ ] Type in a file, immediately switch documents (inside the 500 ms debounce), switch back → edit present, and on disk
- [ ] Type, immediately **close the document** → edit on disk
- [ ] Type, immediately **background the app** → edit on disk
- [ ] Open 9+ files with an unsaved edit in the oldest, return to it → **edit still there** (eviction must refuse to drop unsaved work)
- [ ] GitHub file with an uncommitted edit, open 8+ others, return → edit intact, still marked uncommitted
- [ ] Open `screenshots-tmp/latin1-not-utf8.md` → "Couldn't Open File", and the bytes are **unchanged on disk**

`latin1-not-utf8.md` is a committed fixture for that last check: a Markdown file in
ISO-8859-1, so Vera treats it as text, tries to decode it as UTF-8, and fails at the first
accented character. Verify it survived with:

```bash
shasum -a 256 screenshots-tmp/latin1-not-utf8.md
# 3a6accb69f03ec62d88412f44092735f9c056403d983bee059e693c99a0b5ded
```

Rebuild it byte-for-byte with `python3 screenshots-tmp/make-latin1-fixture.py` if it is
ever damaged. Do not "fix" the encoding: being undecodable is the whole point.

### K. Scroll edges and sidebar opacity

New in `ed34f82`, from the 2026-07-26 iPad screenshots. Build-verified only.

- [ ] **iPad, Preview**: scroll a document → text passes under a defined strip at the top, not a soft fade, and nothing bright sits beside the A/A/Edit cluster
- [ ] **iPad, sidebar**: scroll the file tree → rows cut off cleanly under "Files" and the toolbar icons rather than half-fading into them
- [ ] **iPad**: scroll a document with large white headings → the sidebar's tone does **not** change, no shimmer at its lower-left corner
- [ ] Sidebar keeps its rounded shape and shadow, and reads as opaque rather than flat against the detail
- [ ] **Light mode**: the sidebar tone still looks right (now `secondarySystemBackground`, was glass). Most likely thing to be wrong, since it was chosen from dark-mode screenshots
- [ ] Code blocks and Markdown tables do **not** grow an edge strip across their own first row
- [ ] **iPhone** and **Mac**: no visual change expected. Confirm nothing shifted

### Two leftovers

- [ ] **iPad**: `RepoStatusCard.tsx` in **Edit** mode, tap A/A repeatedly → no hang, no CPU spin (Preview passed, Edit was not retested)
- [ ] **iPhone**: does switching documents still feel workable with no tab bar and no persistent sidebar? A judgement call, not a pass/fail. If it feels wrong, a switcher can go back on iPhone only

---

## Every release

Short standing set. Everything else is covered by the validated list below until the code
around it changes.

- [ ] Type, save, and confirm the edit is on disk after force-quitting the app
- [ ] **iPad**: `RepoStatusCard.tsx` in Preview, tap A/A repeatedly → no hang. Permanent check: this bug came back twice and three "fixes" for it were wrong
- [ ] Open a syntax-highlighted file on all three → highlighting renders correctly
- [ ] GitHub: single-file commit, multi-file commit, branch switch, conflict recovery
- [ ] Light/dark toggle on a code file re-highlights correctly
- [ ] Delete an open file from the sidebar → it closes, no crash

---

## Validated on device, 2026-07-26

The 2026-07-26 rework and the earlier 1.3.1 carry-overs, confirmed by the user except
where listed as open above. Kept as a record so these are not re-run blindly. Re-test a
line only if its code changes.

- **Speed and stability**: switching documents is instant with no spinner, scroll position and mode survive, large files and the line-number gutter scroll smoothly, files over 1 MB open promptly
- **Typography**: no size jump between Edit and Preview, tables match prose, Larger Text moves every surface together, the Mac gutter follows A/A
- **iCloud**: evicted files explain themselves and are cancellable, offline gives a working Try Again
- **iPad font-size hang in Preview**: fixed, see `IPAD_FONT_SIZE_HANG.md`
- **Sidebar as the only document surface**: switching, closing (including the last document), Close Others, dirty indicators, uncommitted-GitHub warning
- **Menus and shortcuts**: full menu bar on Mac, same shortcuts on iPad with a hardware keyboard, ⌘S writes immediately, ⌘, opens Settings, items grey out correctly
- **Find and replace**: native find on both platforms, replace-all keeps highlighting intact and produces one save
- **Folder search**: streams, cancels per keystroke, skips `node_modules` / `.build` / `.git` and gitignored paths, caps at 200 with a footer, reports evicted and oversized files
- **Earlier 1.3.1 items**: the `HighlightrEngine` compile error, the iPad gutter invisible until scrolled, and both font-size hangs. The Edit-mode hang is the one leftover above
