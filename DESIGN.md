# Vera — Design System

Vera's look is **restraint-first and native**: clean, generously spaced, one accent,
no orphan buttons, nothing hidden more than a tap deep. The file tree (your repo /
folder) is the hero; chrome stays quiet so the Markdown reads.

This is the living reference for the visual identity introduced in the 1.1 redesign.
Tokens live in `Vera/Vera/Shared/Theme.swift`.

## Principles

1. **Clean over clever.** Whitespace and hierarchy do the work; depth comes from
   materials, not borders or shadows.
2. **No control buried.** Primary actions are visible; only genuinely-secondary items
   go in an overflow menu — never the whole toolbar.
3. **One accent.** Brand teal is the single tint (selection, buttons, active states).
4. **Native first.** SF Symbols, system materials, Dynamic Type, light/dark parity,
   ≥44 pt touch targets, accessibility labels on every icon-only control.
5. **Consistent states.** Loading / empty / error states share one calm, branded form.

## Colour

- **AccentColor** (asset catalog) — brand teal, app-wide tint.
  - Light `#0B7C7E` (r .043, g .486, b .494) · Dark `#4FC9CE` (r .310, g .792, b .808).
- **BrandTeal** (asset catalog) — saturated fill for hero marks (e.g. the onboarding
  icon tile). Light is the deep teal; dark is the bright cyan.
- Everything else is **semantic system colour** (`.primary`, `.secondary`, `.tertiary`,
  `.bar`, grouped backgrounds) so dark mode and contrast come for free.

## Spacing

4-pt scale via `Theme.Space`: `xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32`.
Default row insets and stack spacing use these — no ad-hoc numbers.

## Radius

`Theme.Radius`: `small 8 · medium 12 · large 20`. Hero tiles use `large`; cards/tiles
`medium`; small chips `small`.

## Typography

Vera ships **no bundled faces** — it leans entirely on the system fonts so the
whole app inherits one accessible, Dynamic-Type-aware ramp for free. The signature
is the monospace, not a custom display face. Tokens/notes live in `Theme.Typography`.

- **UI** — system font, semantic ramp (`.largeTitle`/`.title`/`.title2`/`.headline`/
  `.body`/`.subheadline`/`.footnote`/`.caption`). Weight carries hierarchy, not
  arbitrary size jumps.
- **Monospace = SF Mono** — the signature face, used **identically** in the editor and
  the preview/code blocks so a snippet reads the same whether you're writing or
  reading it. Always via `Font.system(_:design: .monospaced)` (SwiftUI) or
  `(NS|UI)Font.monospacedSystemFont(ofSize:weight:)` (TextKit/Highlightr) — never a
  hardcoded face name like "Menlo". Default size 15; the editor size control spans
  12–32 and the inline-code `.em(0.875)` scales with body text.
- **Reading view** — system text with comfortable line spacing for prose.

## Components

- **Toolbars** — grouped into ≤3 clusters; icon-only buttons carry `.help` (macOS) and
  `.accessibilityLabel`. Overflow `···` holds only secondary actions.
- **Sidebar rows** — clear file vs folder via icon hierarchy: folders carry the
  accent-tinted `folder.fill`, files a muted `doc.text`. The file open in the active
  tab is highlighted in the tree (accent icon + medium weight) so the sidebar and the
  editor stay connected; the Open Files section uses an accent dot for the active tab.
  No hover-only affordances on iOS (actions via swipe / context menu, discoverable).
- **Empty states** — `ContentUnavailableView` with an icon, one line, and at most one
  prominent action (e.g. "Open Folder…").

## Roadmap hooks

The sidebar row model leaves room for **git status / diff badges** — the git-native
direction (see the plan and `project_vera_positioning` memory) renders changed-since
markers here without restructuring.
