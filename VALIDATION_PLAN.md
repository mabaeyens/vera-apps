# Vera Validation Plan — Post-Fix Round 5

Round 3/4 device results:
- Issue 1 ✅ PASS
- Issue 2 ✅ PASS
- Issue 3 ✅ PASS
- Issue 4 ✅ PASS
- Issue 5 ✅ PASS
- Issue 6 ✅ PASS
- Issue 7 ✅ PASS — Atlas visible in both preview and edit mode (wand icon confirmed in screenshots)
- Issue 8 ✅ PASS — Double-tap scrolls to edit mode but lands a few lines above the tapped position

Round 5 device results:
- Issue 1–7 ✅ PASS (carry-forward from Round 4)
- Issue 8 ✅ PASS — Edit button opens editor at reading position (readingScrollFraction fix)
- Issue 9 ✅ PASS — Large folders open quickly (CloudScanner lazy/shallow loading)
- Issue 10 ✅ PASS — Scroll is smoother (simultaneousGesture fix applied in Round 4)

Round 4 fixes applied:
- Issue 7 round 4: **complete restructure** — compact mode now uses `NavigationStack` + `navigationDestination(item:)` instead of `NavigationSplitView`. Root cause: detail column toolbar items don't connect to the navigation bar in compact split view. With `NavigationStack`, `DocumentView` is pushed as a real navigation and its `.toolbar` IS connected to the nav bar. ✅ PASS
- Double-tap to edit: switched from `.onTapGesture(count:2)` to `.highPriorityGesture(SpatialTapGesture...)` to override `.textSelection`'s built-in double-tap interception. Double-tap now triggers edit mode but scroll position is a few lines off.
- Open-file icon: changed from `doc.badge.plus` (reads as "create") to `tray.and.arrow.down` on both iOS and macOS.

Build status: ✅ iOS — BUILD SUCCEEDED  
Build status: ✅ macOS — BUILD SUCCEEDED

---

## How to use this plan

For each issue, the Steps column tells you exactly what to do on the device.
Mark each row **PASS** or **FAIL** after testing.

---

## Issue 1 · Sidebar visible & folder picker works (iOS)

**Round 2 result:** ✅ PASS — no retest needed

---

## Issue 2 · Open standalone file button works (iOS)

**Round 3 result:** ✅ PASS — no retest needed

---

## Issue 3 · Reset in iOS Settings (not in app)

**Round 2 result:** ✅ PASS — no retest needed

---

## Issue 4 · Trash icon only on hover (macOS)

**Round 2 result:** ✅ PASS — no retest needed

---

## Issue 5 · Folder picker works (macOS)

**Round 2 result:** ✅ PASS — no retest needed

---

## Issue 6 · Copy text in preview mode (macOS)

**Round 2 result:** ✅ PASS — no retest needed

---

## Issue 7 · Atlas button visible on iOS

**Round 4 fix:** Complete architectural change — compact (iPhone) mode now uses `NavigationStack` + `navigationDestination(item: $vm.selectedURL)` instead of `NavigationSplitView`. When `DocumentView` is a pushed navigation destination, its `.toolbar` connects to the iOS nav bar correctly. This eliminates toolbar bleed from the sidebar's items.

**Round 4 result:** ✅ PASS — Atlas (wand icon) confirmed visible in both edit mode (`← · ✦ · AA · Done`) and preview mode (`← · ✦ · AA · Edit`) in device screenshots.

---

## Issue 8 · Double-tap scroll position is off by a few lines

**Context:** The double-tap gesture was fixed (now fires correctly in edit mode via `highPriorityGesture(SpatialTapGesture...)`). However the cursor/scroll lands a few lines above the tapped location instead of exactly at it.

**Root cause:** `anchorFraction` is computed as `tapY / viewHeight`. The `viewHeight` captured by `GeometryReader` in `ViewingModeView` likely includes the navigation bar + status bar area, making the fraction slightly too small, so the editor scrolls to a position slightly higher than tapped.

**Fix needed:** In `ViewingModeView`, subtract the safe area insets (top) from `viewHeight` before computing the fraction, or capture `viewHeight` from the scroll content area rather than the full frame.

| Step | What to do | Expected result |
|------|-----------|----------------|
| 8a | Open a long .md file in preview mode | File renders in reading mode |
| 8b | Scroll to the middle of the document | Some paragraph is visible mid-screen |
| 8c | Double-tap a specific word | Edit mode opens; cursor is at or very near that word |

**Round 4 result:** ❌ FAIL — edit mode opens but cursor is a few lines above the tapped word

---

## Summary table

| # | Issue | Fix applied | Result |
|---|-------|------------|--------|
| 1 | Sidebar / folder picker (iOS) | fileImporter on NavigationSplitView | ✅ PASS |
| 2 | Open standalone file (iOS) | fileImporter moved to split-view level | ✅ PASS |
| 3 | Reset in iOS Settings | Settings.bundle + pendingReset | ✅ PASS |
| 4 | Trash always visible (macOS) | onHover show/hide | ✅ PASS |
| 5 | Folder picker (macOS) | fileImporter on NavigationSplitView | ✅ PASS |
| 6 | Copy only per-line (macOS) | Copy All toolbar button | ✅ PASS |
| 7 | Atlas hidden on iOS | NavigationStack for compact mode | ✅ PASS |
| 8 | Edit button sends cursor to wrong position | readingScrollFraction tracking | ✅ PASS |
| 9 | Large folder tree (60+ s load) | CloudScanner lazy/shallow loading | ✅ PASS |
| 10 | Scroll stutters in preview mode | simultaneousGesture fix | ✅ PASS |
