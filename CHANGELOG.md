# Changelog

## v1.1.0

- **GitHub (preview)** — connect a repository with a fine-grained token and browse/read its Markdown directly in Vera. The token talks only to GitHub and lives in your device Keychain.
- **What changed** — when a repo file has moved on since you last opened it, Vera shows a "What Changed" button and a native diff of the changes — built for skimming the Markdown your agents write.
- **Light edit & commit** — edit a repo's Markdown in Vera and commit straight to the branch, or open a pull request (Vera makes the branch). Needs a token with Contents: Read and Write.
- **New brand identity** — a refined teal accent throughout, a consistent design system (spacing, radii, typography), and a refreshed onboarding flow.
- **Cleaner, less-cramped UI** — primary actions (New File, Open) are now visible buttons instead of hidden behind a `···` menu; the macOS document toolbar is grouped; folders carry a tinted icon so they read distinctly from files.
- **Focus Mode** — a one-tap distraction-free writing surface that hides the formatting bar and linter.
- **Flatter formatting bar** — bold, italic, strikethrough, code, heading, list, quote and snippets are all one tap away (no nested menu); every button has an accessibility label.
- **Friendlier empty state** — a clear "No Folder Open" screen with a direct Open Folder action.
- **Reliability & privacy** — fixes a false "Couldn't Load Files" error on launch and moves the folder bookmark into the Keychain.
- **macOS App Sandbox** — the Mac app now runs sandboxed for stronger isolation, with access limited to the folders you pick and outbound network only to GitHub.

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
