# Spec — Accessibility audit & remediation

**Status:** Audit complete. Remediation **F1–F6 and F8 implemented** (builds green,
iOS + macOS); F5 left as-is (already VoiceOver-readable); **F7 deferred**. A device
VoiceOver + Dynamic Type pass is still required before claiming VoiceOver / Larger Text.
**Author:** Miguel A. Baeyens · **Date:** 2026-06-21 · **Scope:** Vera iOS + macOS, target v1.1.1

## Why

Before declaring Apple's **Accessibility Nutrition Labels** in App Store Connect, we
need to know what Vera actually supports — and only claim what's true. This is a
**static** audit (reading the SwiftUI/UIKit/AppKit source). It does **not** replace a
device VoiceOver + Dynamic Type pass; it tells us what to fix *before* that pass and
which labels are safe to claim now.

## Method & baseline

Grepped every `Image`, `Button`, font, and accessibility modifier across `Vera/Vera`.
Current accessibility footprint:

- **27** `accessibilityLabel` (good coverage on icon-only toolbar/sidebar buttons).
- **1** `accessibilityAddTraits` (`TabBarView.swift:166`, `.isSelected` on the active tab).
- **0** `accessibilityHidden`, `0` `accessibilityHint`, `0` `accessibilityValue`,
  `0` `accessibilityElement`.

So: labels are in good shape; decorative-image hiding, selection traits beyond the tab
bar, and Dynamic Type are the weak spots.

### What's already right
- Icon-only buttons in `MacRootView`, `iOSRootView`, `DocumentView`, `AboutView`,
  `FileTreeView` (close tab) carry labels.
- Active tab exposes `.isSelected` (`TabBarView.swift:166`).
- The GitHub token uses `SecureField` (`GitHubBrowserView.swift:110`) — correct for
  privacy and VoiceOver.
- The editor and preview are real `UITextView`/`NSTextView`, which give strong built-in
  text a11y (selection, rotor, reading order) for free.
- Semantic system colours throughout → dark mode and most contrast inherited.

## Findings

| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| F1 | High | **Informative iCloud status icons are unlabeled.** `icloud.and.arrow.down` / `icloud.slash` convey real state (not downloaded / offline) but have no `accessibilityLabel`; macOS has only `.help` (a hint, not a label). VoiceOver announces "image". | `FileTreeView.swift:445` (iOS), `:535`/`:540` (MacFileRow) |
| F2 | High | **No Dynamic Type in the main surfaces.** The editor font is `monospacedSystemFont(ofSize: fontSize)` driven only by the in-app 12–32 control, not `UIFontMetrics`; the system "Larger Text" setting does nothing. Preview inline code / tables and the tab bar use fixed `.system(size:)`. | `HighlightingTextView.swift:48,137,415,494`; `MarkdownDocumentView.swift:213,357`; `TabBarView.swift:133` |
| F3 | Medium | **Decorative images not hidden from VoiceOver.** Leading row icons (Markdown mark, `folder.fill`, repo `</>`), onboarding hero + feature icons are read as "image" before the text. None use `.accessibilityHidden(true)`. | `OnboardingView.swift:14,86`; sidebar rows in `FileTreeView.swift` |
| F4 | Medium | **Selection state without traits outside the tab bar.** The "Open Files" active row uses a filled-vs-clear `Circle` (presence cue, good) but no `.accessibilityAddTraits(.isSelected)`; the active file in the tree relies on accent colour + weight + accent icon (non-colour cues exist) but also has no `.isSelected`. | `FileTreeView.swift` openFileRow (~344–358), fileRow |
| F5 | Low | **Save / commit status is visual-only.** `saveIndicator` shows a spinner + small text; no `accessibilityValue` or announcement on state change, so VoiceOver users may miss "Saving…/Saved/Committed". | `DocumentView.swift` saveIndicator |
| F6 | Low | **Reduce Motion not respected.** Focus-mode sidebar collapse and lint-panel expand use `withAnimation` without checking `accessibilityReduceMotion`. Motion is small, but the toggle is ignored. | `MacRootView.swift` focus `onChange`; `EditingModeView.swift` LintPanel |
| F7 | Low | **Preview structure not exposed.** Rendered headings don't carry the heading trait and tables render as flat `Text` rows (`DocTableBlock`), so the VoiceOver rotor can't jump by heading or read the table as a grid. Reading works; structural navigation doesn't. | `MarkdownDocumentView.swift` |
| F8 | Low | **Placeholder-as-label on GitHub fields.** Owner/repo `TextField`s rely on placeholder text for their a11y label; explicit `.accessibilityLabel` is more robust. | `GitHubBrowserView.swift:120,126` |

## What's claimable on the Nutrition Label

Per platform, only after the noted condition:

| Feature | Now? | Condition |
|---|---|---|
| **Dark Interface** | ✅ Yes | Adaptive; supported today. |
| **Sufficient Contrast** | ⚠️ Verify | Semantic colours help, but check accent teal `#0B7C7E` on white meets 4.5:1 for text. |
| **Differentiate Without Color Alone** | ⚠️ After F4 | Cues are mostly shape/weight already; confirm save/lint colours aren't the *sole* signal. |
| **Reduced Motion** | ⚠️ After F6 | Honour `accessibilityReduceMotion`; motion is minimal anyway. |
| **Voice Control** | ⚠️ After F1 | Needs every control to have a name (labels) — fix the unlabeled status icons. |
| **VoiceOver** | ❌ Not yet | Fix F1/F3/F4, then a **device pass** across core flows before claiming. |
| **Larger Text** | ❌ Not yet | Requires Dynamic Type (F2) in editor + preview, or it's not honest. |
| Captions / Audio Descriptions | n/a | No media. |

## Remediation plan (ordered)

1. **F1 (high, small):** add `accessibilityLabel` to the iCloud status icons ("Not
   downloaded" / "Offline, unavailable"), iOS and macOS. Quick win, unblocks Voice
   Control + VoiceOver clarity.
2. **F3 (medium, small):** `.accessibilityHidden(true)` on purely decorative leading
   icons so VoiceOver reads just the filename; keep `Label`-based rows as-is.
3. **F4 (medium, small):** add `.accessibilityAddTraits(.isSelected)` to the active
   "Open Files" row and active tree file; hide the indicator dot from VoiceOver.
4. **F2 (high, larger):** make the editor and preview honour Dynamic Type — base the
   font on `UIFontMetrics(forTextStyle: .body).scaledFont(...)` (or scale the user's
   chosen size by the content-size category), and replace fixed `.system(size:)` in the
   preview/tab bar with text styles. This is the gate for the "Larger Text" claim.
5. **F6 (low):** wrap the focus/lint animations in a `reduceMotion` check.
6. **F5, F7, F8 (low):** add a save-status `accessibilityValue`; expose heading traits
   / a table representation in the preview; add explicit labels to the GitHub fields.

Then: **device VoiceOver + Dynamic Type pass** on the core flows (open folder → pick
file → read → edit → save; GitHub connect → browse → commit/PR). Only after that, fill
the Nutrition Label per the table above.

## Remediation status (implemented for v1.1.1)

| ID | Status | What changed |
|----|--------|--------------|
| F1 | ✅ Done | iCloud status icons labeled ("In iCloud, not downloaded" / "In iCloud, offline") in `FileTreeView` (iOS row + `MacFileRow`). |
| F2 | ✅ Done | Dynamic Type for mono text: `DynamicTypeSize.monoScale` (`Theme.swift`); editor scales via `EditingModeView.effectiveFontSize` (iOS); preview code + tables scale (`MarkdownDocumentView`); tab labels use a scalable text style (`TabBarView`). macOS keeps the in-app size control. |
| F3 | ✅ Done | Decorative leading icons hidden (`MarkdownFileIcon` left as `Label` icon; folder.fill in HStack rows + onboarding icons get `.accessibilityHidden(true)`). |
| F4 | ✅ Done | `.accessibilityAddTraits(.isSelected)` on the active Open-Files row, active tree file, and `MacFileRow`; indicator dots hidden from VoiceOver. |
| F5 | ➖ As-is | Save/commit states already render text VoiceOver can read; proactive announcements deferred (low value). |
| F6 | ✅ Done | Focus collapse (`MacRootView`, `DocumentView`) and lint-panel expand respect `accessibilityReduceMotion`. |
| F7 | ⏸ Deferred | Heading-trait / table-grid VoiceOver semantics in the preview — larger renderer change, low priority. |
| F8 | ✅ Done | Explicit `accessibilityLabel`s on the GitHub token / owner / repo fields. |

Both platforms build green. Still pending: the on-device VoiceOver + Dynamic Type pass,
then fill the Nutrition Label (VoiceOver, Larger Text, Voice Control, Reduced Motion,
Differentiate Without Color, Sufficient Contrast, Dark Interface).

## Out of scope
- Running VoiceOver/Voice Control on device (requires hardware; this audit is static).
- Full table-grid VoiceOver semantics in the preview (tracked as F7, low priority).
- Localization of accessibility strings.

## Device pass & Nutrition Label procedure

**Status:** open (2026-07-10). F1–F6 and F8 are code-remediated (table above); this
section defines the on-device verification pass still needed before claiming VoiceOver
or Larger Text on the Nutrition Label, and how to fill the label once it passes.

### VoiceOver pass checklist
Walk these core flows with VoiceOver on, on a real iOS device **and** a Mac:
- File tree navigation (open folder → browse → select a file).
- Open → edit → save a document.
- GitHub sign-in → browse a repo → commit / open a PR.
- Toggle focus mode; expand/collapse the lint panel.

Confirm while walking:
- **F1** — iCloud status icons are announced ("In iCloud, not downloaded" / "In iCloud,
  offline"), not silent or "image".
- **F3** — decorative leading icons (Markdown mark, folder icon, repo `</>`) are silent;
  only the filename/label is read.
- **F4** — selection state is announced on the tab bar, the active Open-Files row, and
  the active file in the tree (not just implied by colour/weight).
- **F6** — focus-mode collapse and lint-panel expand don't animate when Reduce Motion is
  on (device setting, not just the in-app check).

### Dynamic Type pass checklist
Cycle through accessibility text sizes — iOS: Settings → Accessibility → Display & Text
Size; macOS: System Settings → Accessibility → Display — and confirm:
- Editor font (mono text, `DynamicTypeSize.monoScale`) scales without clipping.
- Preview inline code and tables scale and stay legible at the largest sizes.
- Tab bar labels scale without truncating or breaking layout.

### Nutrition Label mapping
Use the "What's claimable on the Nutrition Label" table above as the source of truth.
This checklist is what flips each ⚠️/❌ row to ✅:
- **VoiceOver** → ✅ once the VoiceOver pass checklist above is clean on both platforms.
- **Larger Text** → ✅ once the Dynamic Type pass checklist above is clean on both
  platforms.
- **Voice Control**, **Reduced Motion**, **Differentiate Without Color Alone**,
  **Sufficient Contrast** → already conditionally claimable per the table; re-confirm
  during the same device pass since it's low extra cost.

### Output
Record a pass/fail note per checklist item, dated, in this file (or a linked note) —
so a future session can tell what's actually been verified on-device versus what's only
been code-audited. Don't fill the Nutrition Label from the static audit alone.
