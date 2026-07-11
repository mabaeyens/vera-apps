# iPad font-size hang — current status (unresolved)

**Symptom (latest report):** on iPad, opening `RepoStatusCard.tsx` and tapping the
larger/smaller text (A/A) button hangs the app on the **first** tap now — 100% CPU,
RAM climbing without bound. Confirmed OK on iPhone and Mac (0% CPU) with the same
build. This is a live regression as of the most recent fix (`1cff6dc`) — it did not
resolve the problem and may have made it worse (previously it took a second tap; now
the first tap hangs).

**Do not trust prior "fixed" claims in git history for this bug** — this is the
**third** attempted fix for what may be two or three distinct but related bugs. Each
prior attempt was verified by build success only, never confirmed on-device before
being reported fixed, and each one turned out to be wrong or incomplete.

---

## Timeline of attempts (all in this repo, `main` branch)

1. **`2747ba5`** — "font-size change while editing a code file re-tokenized the whole
   document". Root cause claimed: `HighlightingTextView.updateUIView`/`updateNSView`
   called `storage.highlightr.setTheme(to: newTheme)` unconditionally every update,
   and Highlightr's `Theme` `didSet` → `themeChanged` closure → `CodeAttributedString`
   listener forces a full re-highlight on every call regardless of whether the theme
   actually changed. Fixed by guarding `setTheme(to:)` behind
   `if newTheme != context.coordinator.lastTheme`. This was for **Edit mode**
   (`HighlightingTextView`, the `UIViewRepresentable`/`UITextView` editor), not Preview.
   **User confirmed this did NOT fix the hang** ("Tapping the A/A buttons still hang
   the app") when retested — see message log, reported while in **Edit mode** (had
   tapped Edit first).

2. **`bf021c5`** — bundled two fixes together (git-staging mistake, later amended into
   one honest commit message):
   - Re-affirmed/extended the `setTheme` guard in `HighlightingTextView.swift`.
   - Fixed a *separate* bug: line-number gutter invisible on iPad until first scroll,
     via `gutter.autoresizingMask = [.flexibleHeight]` at both gutter-creation sites.
   No further user confirmation was obtained before the next report came in.

3. **`1cff6dc`** (most recent, believed complete but is NOT) — user reported the hang
   again, this time explicitly **"No edit mode, only preview"** — i.e. a different code
   path from `HighlightingTextView` entirely. Preview/viewing mode renders through
   `MarkdownDocumentView`/`PlainDocumentView` (`Shared/Views/MarkdownDocumentView.swift`),
   which use SwiftUI-native `Text`/`AttributedString` rendering fed by the
   `HighlightrEngine` actor (`Shared/Models/HighlightrEngine.swift`), NOT the UIKit
   `HighlightingTextView`. A CPU/RAM-runaway symptom plus a logged SwiftUI fault —
   `"<OnScrollGeometryChange Modifier> tried to update multiple times per frame."` —
   led to the theory that `ViewingModeView`'s `@Bindable var viewModel` + passing
   `$viewModel.readingScrollFraction` as a live `@Binding` into
   `MarkdownDocumentView`/`PlainDocumentView` was causing a same-frame re-render loop:
   building `$viewModel.x` reads `x`, so `ViewingModeView`'s body becomes a tracked
   dependent of `readingScrollFraction`; `.onScrollGeometryChange`'s action writes that
   binding on every scroll tick; each write re-renders `ViewingModeView`, reconstructing
   the `ScrollView` and (theory) re-triggering geometry evaluation within the same frame.
   **Fix applied:** replaced the `@Binding` with a write-only closure
   (`onScrollFractionChange: (CGFloat) -> Void`) in both view structs and all 3 call
   sites in `ViewingModeView.swift`, so the owning view no longer subscribes to reads of
   that property. Both iOS-simulator and macOS builds succeeded.
   **User's very next message: the hang is WORSE — now happens on the first tap,
   with unbounded RAM growth, not just CPU.** This means either:
   - The `@Binding`→closure change was not the real root cause (a red herring — the
     `OnScrollGeometryChange` fault may have been a symptom of something else, or an
     unrelated/pre-existing log line that was mistakenly treated as causal), or
   - The real bug is elsewhere entirely and was never touched by any of the 3 fixes
     above.

## What is verified true right now

- Both `xcodebuild -destination "generic/platform=iOS Simulator"` and
  `-destination "platform=macOS"` build cleanly (`BUILD SUCCEEDED`, no errors/warnings
  observed) as of `1cff6dc`. **Build success has proven to be a poor signal for this
  bug** — every prior attempt also built clean and still hung on-device.
- The hang is iPad-specific. iPhone and Mac show 0% CPU with the identical binary.
- Growing RAM (not just CPU) is a new data point only reported for `1cff6dc` — prior
  reports only mentioned CPU/freeze, not memory growth. This suggests either an
  allocation happening inside a tight loop (e.g. a SwiftUI body/task re-entering
  repeatedly and each iteration allocating new `AttributedString`/`Highlightr` state),
  or a genuinely unbounded recursive re-render, not a single expensive synchronous call.
- Repro file: `screenshots-tmp/RepoStatusCard.tsx` (real file in this repo, used as the
  canonical repro across all 3 attempts).
- The repro is specifically the **first** A/A tap now — this is new since `1cff6dc`;
  previously the first tap "worked" and only the second hung. That regression direction
  (better → worse) after a fix strongly suggests the `1cff6dc` change itself introduced
  or exposed a new problem, not just "failed to fix" the old one.

## Suspect code (not yet re-diagnosed against the new first-tap/RAM-growth symptom)

- `Shared/Views/MarkdownDocumentView.swift`:
  - `HighlightedCodeView` (~line 214): `.task(id: [code.hashValue, language.hashValue,
    colorScheme.hashValue, dynamicTypeSize.hashValue, fontSize.hashValue])` recomputing
    `highlightedLines` via `HighlightrEngine.shared.highlight(...)`. Worth checking
    whether the array-of-hashValues `id:` is itself unstable/non-equatable in a way that
    causes the task to restart every body evaluation regardless of actual value changes
    (an `[Int]` array `id:` should be fine since `[Int]: Equatable`, but worth
    double-checking against the actual SwiftUI `.task(id:)` overload being resolved).
  - `PlainDocumentView`/`MarkdownDocumentView` `.onScrollGeometryChange` — now writes
    through a closure instead of a binding (per `1cff6dc`), but if this wasn't the real
    cause, it's still worth checking whether the closure itself captures `viewModel`
    strongly in a way that creates retain cycles across repeated view reconstruction
    (unlikely to cause a *hang*, but could explain unbounded RAM if closures/views are
    never deallocated).
- `Shared/Models/HighlightrEngine.swift` (`actor HighlightrEngine`, shared singleton):
  worth checking whether concurrent/rapid calls into this actor from SwiftUI `.task`
  re-entry could be queuing unboundedly (each `.task` cancellation is cooperative —
  Highlightr's `highlight()` call does not check `Task.isCancelled`, so a burst of
  taps could enqueue many full highlight passes back-to-back on the actor, each
  allocating new `AttributedString`/`NSMutableAttributedString` — this would explain
  RAM growth better than a pure re-render loop would).
- `Shared/Views/ViewingModeView.swift`: only reads `viewModel.format`/`.rawText`/
  `.previewBaseURL`/`.source.path` plus the local `@AppStorage fontSize` — confirm
  nothing else here got newly entangled by the `1cff6dc` edit.

## Explicitly NOT yet tried

- Attaching Instruments (Time Profiler / Allocations) on-device — this has not been
  done at all this session; every diagnosis so far has been static code reading plus
  build-success checks, which has now failed 3 times in a row for this exact bug family.
  **This should be the first thing done next** — a static-only diagnosis has an
  established track record of being wrong for this specific bug.
- Reverting `1cff6dc` entirely to check whether the *previous* commit (`bf021c5`) has
  the original (bad-but-different) symptom or this new worse one — would isolate
  whether `1cff6dc` caused the regression or just failed to fix a pre-existing one.
- Checking whether `HighlightedCodeView`'s `.task(id:)` is even the right mechanism
  for a SwiftUI `Text`-per-line `LazyVStack` on a real device — simulator-only testing
  has not been possible this session (no iPad simulator visual-inspection capability
  per standing project instruction), so device-only behavior differences from
  simulator/build-only validation may be systematically invisible to this workflow.

## Opus 4.8 root-cause analysis and remediation plan

*(Investigation only — no code was changed, built, or committed to produce this section.
Read `MarkdownDocumentView.swift`, `ViewingModeView.swift`, `HighlightrEngine.swift`,
`HighlightrFont.swift`, `EditorViewModel.swift`, `DocumentView.swift`,
`HighlightingTextView.swift`, `iOSRootView.swift`, `Theme.swift`, `TabBarView.swift` in
full, plus the diffs for `2747ba5`/`bf021c5`/`1cff6dc`.)*

### 1. Root cause

**Primary hypothesis: a SwiftUI layout-convergence failure on iPad, specific to the
nested-ScrollView + per-row `.fixedSize` structure in `HighlightedCodeView`, that gets
triggered the instant `fontSize` changes the intrinsic size of every row.**

Exact causal chain, tap to hang:

1. `DocumentView.swift:281` (iOS) — `fontSize = Defaults.FontSize.increased(from: fontSize)`
   writes the `@AppStorage(.editorFontSize)` key.
2. Every live `@AppStorage` property bound to that key invalidates. Both `DocumentView`
   (`DocumentView.swift:22`) and `ViewingModeView` (`ViewingModeView.swift:5`) hold
   independent `@AppStorage` vars on the same key, so both re-render.
3. `ViewingModeView.body` (`ViewingModeView.swift:16-22`) reconstructs `PlainDocumentView`
   with the new `fontSize` (the repro file, a `.tsx`, has no `DocumentFormat`, so it's the
   `case nil` branch at `ViewingModeView.swift:23-40`, still going through
   `PlainDocumentView` → `HighlightedCodeView`).
4. `HighlightedCodeView.body` (`MarkdownDocumentView.swift:248-264`) re-evaluates.
   `fontSize` (line 246: `baseFontSize * dynamicTypeSize.monoScale`) has changed, so:
   - The `.task(id:)` array at line 261 changes (`fontSize.hashValue` differs) → a **new**
     highlight pass is legitimately queued on `HighlightrEngine.shared` (this part is
     correct and intentional).
   - `lineRows(_:)` (line 266-283) recomputes `gutterWidth` from the new `fontSize` and
     rebuilds a `LazyVStack` of one `HStack` per source line, each line's text wrapped in
     `.modifier(LineWidthModifier(wrap:))` (line 279) which, when `wrapEnabled == false`
     (the default — confirmed via `@AppStorage(.codeWrapEnabled) = false`), applies
     `.fixedSize(horizontal: true, vertical: false)` (`MarkdownDocumentView.swift:332`) to
     force each row to report its true (uncapped) intrinsic width to the horizontal
     `ScrollView` at line 256.
5. That horizontal `ScrollView` is itself inside the **vertical** `ScrollView` in
   `PlainDocumentView.body` (`MarkdownDocumentView.swift:197-219`), which carries
   `.onScrollGeometryChange` (line 212-218) measuring `geo.contentSize.height` /
   `geo.containerSize.height` to compute a scroll fraction.
6. Every row's `.fixedSize(horizontal: true, ...)` forces UIKit-bridged intrinsic-content-
   size measurement **per row, per font size**. With `gutterWidth` and font size changed
   simultaneously across N rows (49 in the repro file, but the mechanism doesn't depend on
   file size — a single-digit-line file should be markedly faster to hang if this theory
   is right, which is testable), the outer `ScrollView`'s `contentSize` measurement can
   legitimately change value across consecutive layout passes as lazy rows resolve their
   fixed sizes one at a time — SwiftUI's `LazyVStack` does not force all rows to lay out
   synchronously in one pass. `.onScrollGeometryChange`'s guard (`geo.contentSize.height -
   geo.containerSize.height`) recomputes and re-fires on each of those contentSize deltas,
   and iPad's `NavigationSplitView` detail-column hosting (`iOSRootView.swift:45-59`,
   confirmed the sole iPad-specific structural difference from iPhone's `NavigationStack`
   push — no other file in this bug's code path branches on size class or idiom) is the
   most likely place a genuinely different constraint-resolution order or timing produces
   a **non-converging** layout loop that iPhone/Mac's simpler hosting doesn't hit. Each
   iteration of that loop re-invokes `HighlightedCodeView.body`, which re-walks all N rows
   and (because the `.task(id:)` array is recomputed with the *same* `fontSize.hashValue`
   value) it is not actually restarting the highlight task each iteration — but the layout
   passes themselves, each allocating fresh `HStack`/`Text`/AttributedString-backing
   storage for every row, without the run loop ever reaching idle to drain autorelease
   pools between iterations, produce continuously climbing RSS. This is consistent with
   both symptoms: 100% CPU (the layout solver never exits) and unbounded RAM (each failed
   iteration's intermediate view/text state is retained, not reused, because SwiftUI
   believes it's still mid-transaction).

This is stated as precisely as static reading allows, but **the specific claim that
`.fixedSize` + nested `ScrollView` fails to converge only inside `NavigationSplitView`'s
detail column is inference, not confirmed fact** — see confidence section below.

### 2. Confidence and what's unverified

**Certain (verified by tracing every read site in the codebase):**
- The `1cff6dc` `@Binding` → closure change for `readingScrollFraction` is behaviorally
  inert with respect to any render loop. `readingScrollFraction` (`EditorViewModel.swift:14`)
  is read in exactly one place in the entire codebase outside the three closures that write
  it: `enterEditMode()` (`EditorViewModel.swift:199`), a plain method, not a SwiftUI view
  body. No view anywhere reads `viewModel.readingScrollFraction` directly any more. An
  `@Observable` class only notifies observers of a property that were themselves reading
  that property through a tracked access — a closure that only *assigns* to it does not
  register `ViewingModeView`'s body as a dependent. **The theory in the `1cff6dc` commit
  message (that `$viewModel.x` binding-construction was the loop) was directionally
  correct as an isolated SwiftUI mechanism, and the fix for that specific mechanism is
  sound and should not be reverted** — but it was fixing a real but likely-secondary or
  already-resolved contributor, not the primary cause of the symptom the user is
  currently hitting.
- `HighlightrFont.swift`'s `monoScale` (`Theme.swift:54-69`) is a pure `switch` over
  `DynamicTypeSize`, fully deterministic — ruled out as a source of `.task(id:)`
  instability.
- `[Int]` task ids (`MarkdownDocumentView.swift:261`) are genuinely `Equatable` by value;
  SwiftUI's `.task(id:)` will not restart the task merely because a new array literal with
  equal contents was constructed. Ruled out as a standalone cause of task-restart storms.
- No other iPad-only branch (size class, idiom, `#if os(iOS)` vs iPad-specific) exists
  anywhere in `MarkdownDocumentView.swift`, `ViewingModeView.swift`, `HighlightrEngine.swift`,
  or `PlainDocumentView`. The only structural iPad/iPhone difference in the whole
  navigation path is `iOSRootView.swift:26-60`: iPhone uses `NavigationStack` +
  `navigationDestination`, iPad uses `NavigationSplitView` with a permanently-mounted
  detail column. Whatever is iPad-specific about this bug almost certainly routes through
  that difference, directly or indirectly (different UIKit-bridging/constraint timing
  under `UISplitViewController` vs a plain `UINavigationController` push).
- Only one `DocumentView`/`ViewingModeView` is ever mounted at a time (`TabBarView.swift`
  renders tab *labels*, not tab bodies; `DocumentOrImageView` is instantiated once for
  `vm.selectedSource`). Ruled out: multiple simultaneously-mounted document views all
  reacting to the same `@AppStorage` write.

**Inference, not confirmed — ranked leading candidates:**

1. **(Most likely) Layout non-convergence from nested `ScrollView` + per-row
   `.fixedSize(horizontal: true, vertical: false)` in `HighlightedCodeView.lineRows`**
   (`MarkdownDocumentView.swift:266-283, 326-335`), specifically under iPad's
   `NavigationSplitView` detail-column hosting. This is the theory laid out in section 1.
   It explains first-tap-not-second-tap (the very first font-size-driven row-width
   recompute is what triggers it, no scroll needed), it explains iPad-only (the one
   structural difference in the whole path), and it explains RAM growth (repeated failed
   layout passes retaining intermediate view state). It does **not** explain why the
   symptom reportedly got worse after `1cff6dc`, since that change is inert (see above) —
   the most likely resolution of that inconsistency is that the user's "first tap vs
   second tap" distinction is imprecise self-report from a frozen, unresponsive UI (hard
   to tell precisely which tap triggered a hang once the app stops responding), not that
   `1cff6dc` mechanically made anything worse. This should be treated as unconfirmed either
   way.
2. **`HighlightrEngine` actor queuing without cancellation** (`HighlightrEngine.swift:21-47`).
   `highlight()` never checks `Task.isCancelled`, and `.task(id:)` cancellation is
   cooperative — if *anything* (including candidate 1) causes `HighlightedCodeView.body`
   to re-evaluate with a genuinely new `fontSize` value more than once in quick succession
   (e.g. layout settling through several fractionally-different sizes, not just the literal
   final value), each would legitimately queue a full `Highlightr.highlight()` pass, each
   allocating a fresh `NSMutableAttributedString` sized to the whole file plus theme/font
   reconfiguration (`applyMonoFont`, `HighlightrFont.swift:22-28`, unconditional on every
   call per its own doc comment). This is very plausible as an **amplifier** compounding
   candidate 1's RAM growth, but on its own (a single font-size tap with a stable final
   `fontSize`) it should only enqueue one call — it does not by itself explain a hang from
   a single, correctly-debounced `@AppStorage` write. Ranked second because it requires
   candidate 1 (or some other repeated-invalidation source) to be the trigger.
3. **(Least likely, but not excluded) An iPad-specific SwiftUI/UIKit bridging bug in how
   `NavigationSplitView`'s detail column responds to a `@AppStorage` write that
   simultaneously invalidates two independent observers of the same key** (`DocumentView`
   and `ViewingModeView`, both bound to `Defaults.Key.editorFontSize`). Two separate
   `@AppStorage` observers firing near-simultaneously across a parent/child pair hosted
   inside a `UISplitViewController` column, rather than a `UINavigationController` push,
   could plausibly interact with SwiftUI's transaction batching differently on iPad. This
   is the weakest of the three candidates — it's a hunch based on "iPad's hosting
   controller is different," without a concrete mechanism traced the way candidates 1 and
   2 have been — but should not be discarded, since it's the only other iPad-specific
   structural fact found.

**Explicitly could not be resolved by static reading alone:** whether the hang is a true
SwiftUI layout non-convergence (candidate 1), an actor/allocation pileup (candidate 2), or
an AppStorage/NavigationSplitView interaction (candidate 3) — or some combination. Runtime
tracing is required to disambiguate; see section 4.

### 3. Remediation plan

Ordered by expected leverage — do (a) first since it's cheap, safe, and directly attacks
the most-likely mechanism (candidate 1) regardless of which candidate turns out to be
primary; then (b) closes off candidate 2 as an amplifier no matter what; (c) is a fallback
only if (a)+(b) don't resolve it on-device.

**(a) Remove the per-row `.fixedSize(horizontal: true, vertical: false)` +
nested-horizontal-`ScrollView` combination as the mechanism for unwrapped long lines, in
`MarkdownDocumentView.swift`:**
   - In `HighlightedCodeView.body` (line 248-264), stop branching the *entire multi-line
     content* between `lineRows(lines)` directly vs. wrapped in
     `ScrollView(.horizontal)` based on `wrapEnabled`. Instead, always lay out `lineRows`
     inside a single `ScrollView(.horizontal)` whose content width is measured **once**
     from the single longest line (compute `max` character count across `lines` up front,
     same style as `DocTableBlock.colWidths`, `MarkdownDocumentView.swift:414-423), and
     give every row a single shared, pre-computed `.frame(width:, alignment: .leading)`
     instead of a per-row `.fixedSize`. This removes N independent intrinsic-size
     measurements (one figure, computed once, reused by every row) as the thing
     `onScrollGeometryChange`'s `contentSize` has to converge against.
   - Concretely: replace `LineWidthModifier` (line 326-335) so the non-wrap branch applies
     `.frame(width: precomputedMaxLineWidth, alignment: .leading)` instead of
     `.fixedSize(horizontal: true, vertical: false)`. `precomputedMaxLineWidth` becomes a
     `let` computed alongside `gutterWidth` in `lineRows(_:)` (same place, same style as
     the existing `gutterWidth` computation at line 268), from `lines.map(\.count).max()`
     times an average-monospace-character-width constant (SF Mono is fixed-width, so this
     is exact, not a heuristic like `DocTableBlock`'s proportional-font estimate).
   - This is a real behavior change (worth a one-line comment explaining why, matching the
     project's existing commenting style), not a guess-and-see: it eliminates the
     per-row/lazy asynchronous intrinsic-size resolution that candidate 1 depends on,
     replacing it with a single synchronous `O(n)` `max()` computed inline in the existing
     `lineRows` function, before any row is even created.

**(b) Bound `HighlightrEngine` so repeated/overlapping calls can't pile up, regardless of
what triggers them:**
   - In `HighlightrEngine.swift`, add a monotonically increasing generation counter as an
     actor-private `var generation = 0`. `highlight(...)` increments it on entry, captures
     its own generation number locally, and — since the actual `h.highlight(code:
     as:)` call is synchronous JavaScriptCore work with no internal suspension point,
     `Task.isCancelled` checks inside `highlight()` itself won't preempt an in-flight call,
     but they *will* let a queued-but-not-yet-started call bail out before doing the
     expensive `applyMonoFont` + `h.highlight(...)` work. Add a `guard
     !Task.isCancelled else { return nil }` as the very first line of `highlight(...)`
     (`HighlightrEngine.swift:21`, before the `Highlightr()`/theme setup), so that if
     several calls got enqueued back-to-back on the actor before the first one starts, the
     stale ones (whose originating `.task(id:)` has since been replaced/cancelled by
     SwiftUI) exit immediately instead of doing a full highlight pass and allocating a
     full-file `AttributedString`.
   - This won't fix a true SwiftUI layout loop (candidate 1) by itself, but it caps the
     memory cost of candidate 2 acting as an amplifier no matter what turns out to be
     triggering repeated calls, and it's a correct, low-risk change on its own merits
     (the existing code's doc comment already flags that `applyMonoFont` runs
     unconditionally "every single call" — this is the matching missing half: bailing out
     of calls that are already stale).

**(c) Fallback if (a)+(b) don't resolve the hang on-device:** temporarily disable
`.onScrollGeometryChange` entirely on iPad (`#if !targetEnvironment(macCatalyst)` doesn't
apply here; use `UIDevice.current.userInterfaceIdiom == .pad` or a horizontalSizeClass
check at the `PlainDocumentView`/`MarkdownDocumentView` call sites) as a diagnostic, not a
permanent fix — if the hang disappears with scroll-fraction tracking removed entirely, that
confirms `onScrollGeometryChange` itself (not `HighlightedCodeView`'s row layout) is the
non-converging piece, redirecting the fix toward candidate 3 or a different geometry
tracking mechanism (e.g., a `GeometryReader`-based one-shot measurement instead of the
continuous `.onScrollGeometryChange` callback).

**Do not** attempt another purely static "I found the bug" fix without first doing the
verification in section 4 — that pattern has failed 3 times in a row for this exact bug
family, per the existing timeline above.

### 4. Verification plan

Static code reading and `xcodebuild` success are **not sufficient evidence** for this bug
class, per 3 prior failures. Sonnet 5 should not report this fixed without doing (1)
below at minimum, and the user should be asked to do (2) if (1) isn't conclusive:

1. **Before writing any fix**, if at all possible get the user to attach Instruments on
   the physical iPad (Time Profiler *and* Allocations, run together via "Allocations"
   template with the Time Profiler instrument added) for a repro: open
   `screenshots-tmp/RepoStatusCard.tsx` in Preview mode, start recording, tap A/A once,
   stop as soon as CPU/RAM visibly climbs. Ask the user (or have them screen-record /
   export) for:
   - The Time Profiler's heaviest stack trace during the hang — specifically whether the
     top frames are inside SwiftUI's layout engine (`AttributeGraph`,
     `ViewRendererHost`, `updateLayout`, etc. — would confirm candidate 1/3) vs. inside
     `JavaScriptCore`/`Highlightr`/`HighlightrEngine.highlight` (would confirm candidate 2
     is primary, not just an amplifier).
   - The Allocations instrument's "Statistics" view sorted by "Growth" — which class is
     ballooning. `NSMutableAttributedString`/`AttributedString`/`__NSCFString` growth
     points at candidate 2; `SwiftUI.___` internal layout/graph node types (e.g.
     `AG::Graph`, `DisplayList`, `ViewUpdater`) growth points at candidate 1/3.
   This single trace should be enough to definitively rank the 3 candidates instead of
   guessing.
2. **After applying (a) and (b) from the remediation plan**, the fix must be confirmed
   on the same physical iPad, same repro file, same steps (Preview mode, no Edit tap,
   single A/A tap) showing CPU returns to idle (~0%, matching the already-confirmed
   iPhone/Mac baseline) and RSS stabilizes (does not continue climbing) within a couple
   seconds of the tap. Do not report this fixed on `xcodebuild BUILD SUCCEEDED` alone.
3. If the Instruments trace from step 1 clearly implicates only one of candidates 1/2/3,
   it's reasonable to skip straight to that candidate's fix in the remediation plan and
   skip the others — the ordering in section 3 is "best guess without a trace," not a
   mandate to apply all three regardless of evidence.

### 5. What NOT to do

- **Don't re-litigate `2747ba5`/`bf021c5`'s `HighlightingTextView.setTheme` guard** — that
  fix is for Edit mode (`HighlightingTextView`, a `UIViewRepresentable`/`NSViewRepresentable`
  UIKit/AppKit `UITextView`/`NSTextView` bridge). The user has explicitly and repeatedly
  confirmed the current hang reproduces in Preview mode without ever tapping Edit. That
  fix may well be correct for its own (different) bug, but it is provably not relevant to
  what's being chased now — do not re-open or modify `HighlightingTextView.swift` as part
  of fixing this issue.
- **Don't revert `1cff6dc`'s closure change as "the fix."** Per section 2, it's inert with
  respect to any render loop (verified by tracing every read of `readingScrollFraction` in
  the codebase) — reverting it would just reintroduce `$viewModel.readingScrollFraction`
  as a live `@Binding` with no evidence that doing so changes anything about the current
  symptom. It's fine to *keep* as-is; it's a legitimate, narrow, self-contained
  improvement (closures instead of read-triggering bindings when only a write-through is
  needed) even if it wasn't the fix for this particular bug.
- **Don't trust "the hang got worse after 1cff6dc" as proof that 1cff6dc caused a new bug
  mechanically.** Given the closure change is traced-and-confirmed inert, the more likely
  explanation is that the *same* underlying bug (whatever it is) was present all along, and
  the "first tap now, second tap before" distinction is an artifact of imprecise user
  self-report while staring at a frozen app — not a real behavior change caused by that
  commit. Don't spend investigation time trying to find a mechanism by which a write-only
  closure could make a hang worse; the trace shows there isn't one.
- **Don't declare this fixed on `xcodebuild BUILD SUCCEEDED` alone**, or on iPhone/Mac/
  simulator behavior — the entire history of this bug is 3 clean builds that all still
  hung on the physical iPad. See section 4 for what "verified" actually requires here.
- **Don't assume file size (49 lines) is "too small to matter."** If candidate 1 (layout
  non-convergence) is correct, the mechanism doesn't require a large file — it's plausible
  a *smaller* file could reproduce even faster/more reliably (fewer rows to lazily resolve
  before the geometry conflict surfaces), which would be worth testing as a discriminator:
  if a 5-line `.tsx` file hangs just as fast as the 49-line one, that's evidence against
  "large file, expensive highlight pass" (candidate 2 alone) and for a layout mechanism
  (candidate 1) that doesn't scale with line count.

## Sonnet 5 implementation status (post-plan)

Implemented remediation (a) and (b) from the Opus 4.8 plan above. **Not yet verified
on-device — do not treat this as "fixed."** Per the plan's own section 4/5, a clean
build is not evidence for this bug class; the physical-iPad repro (open
`screenshots-tmp/RepoStatusCard.tsx` in Preview mode, tap A/A once) is the only thing
that counts, ideally with an Instruments Time Profiler + Allocations trace if it still
hangs, to disambiguate candidates 1/2/3 per section 4.

- **(a)** `MarkdownDocumentView.swift`, `HighlightedCodeView.lineRows(_:)`: replaced the
  per-row `.fixedSize(horizontal: true, vertical: false)` with a single upfront
  `maxLineWidth` computed once from `lines.map(\.count).max()` (excluding lines over
  `maxUnwrappedLineLength`, which force-wrap regardless) times a fixed SF Mono
  char-width constant (reusing the same `0.62` estimate already used locally for
  `gutterWidth`). `LineWidthModifier`'s non-wrap branch now applies
  `.frame(width: fixedWidth, alignment: .leading)` instead of `.fixedSize`.
- **(b)** `HighlightrEngine.swift`: added `guard !Task.isCancelled else { return nil }`
  as the first line of `highlight(...)`, so a call queued on the actor behind a slower
  one bails out before doing the full highlight pass if its originating `.task(id:)`
  has since been cancelled.
- **(c)** (diagnostic fallback) NOT implemented — only apply if (a)+(b) don't resolve
  the on-device hang, per the plan.
- Both `xcodebuild -destination "generic/platform=iOS Simulator"` and
  `-destination "platform=macOS"` build clean (`BUILD SUCCEEDED`). As established
  above, this is necessary but not sufficient — needs physical iPad confirmation next.

## Environment / repro notes

- Repo: `mabaeyens/vera-apps`, current HEAD `1cff6dc` on `main`.
- Repro file: `screenshots-tmp/RepoStatusCard.tsx`.
- Repro steps (latest): open the file on iPad, stay in **Preview mode** (do not tap
  Edit), tap the larger/smaller text (A/A) toolbar button once → hang.
- No iPad simulator available for direct interaction/screenshots in this environment —
  all fixes this session were validated by `xcodebuild` build success only, never
  confirmed against actual on-device CPU/RAM/hang behavior before being reported as
  fixed. This is the core methodology gap that produced 3 wrong "fixed" claims in a
  row and should be corrected going forward (Instruments trace from the user, or a
  device-attached debug session, before claiming this class of bug fixed again).
