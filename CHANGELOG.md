# Changelog

## v1.0.36

- Security hardening (path traversal fixes, bookmark validation) and HIG accessibility improvements (labels, touch targets, dark mode). VSCode-style sidebar now stays persistent — only the toolbar button toggles it.

## v1.0.35

- **Security audit** — path traversal hardening, `hasPrefix` → `starts(with:)` migration,
  bookmark validation; `PrivacyInfo.xcprivacy` added to project
- **HIG audit** — accessibility labels on all icon buttons, touch target sizing, dark mode
  colour fixes, API modernisation
- **VSCode-style sidebar** — persistent left panel that only the toolbar button can hide
  (never auto-collapses); macOS folder picker fixed
- Doc rationalisation — README/PROJECT split; stale files removed

## v1.0.34

- **Markdown preview overhaul** — native `UITextView`/`NSTextView` with full cross-block
  selection and rich-text copy; replaces MarkdownUI dependency
- **Syntax-highlighted preview** — fenced code blocks with atom-one theme via Highlightr
- **Table rendering** — structured table view
- **Always-visible tab bar** — tab bar shows from the first open file; `+` opens file picker
- **Linter auto-fix** — repairs heading spacing, blank lines, trailing whitespace, smart quotes
- Horizontal rule overflow fix; cold-launch Highlightr crash fixed

## v1.0.33

- macOS formatting shortcuts, right-click context menu
- Atlas cheat sheet improvements
- Formatting entry point unified to wand icon

## v1.0.32

- Slow folder loading fixed — off-main-thread scan with 10 s timeout
- iOS UI revamp — clean preview mode, formatting bar in edit mode slides with keyboard
