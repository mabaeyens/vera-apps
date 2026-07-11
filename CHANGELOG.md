# Changelog

## v1.3.0

**File browsing & viewing**
- Browse, view, and syntax-highlight any text file, not just Markdown — Python, Swift, Go, Rust, shell, JSON, YAML, SQL, TypeScript/TSX, JavaScript/CJS, and more
- Curated per-language file icons in the tree
- Wrapper extensions (`.template`, `.sample`, `.example`, `.dist`, `.orig`) now highlight using their inner file type
- New "wrap" toggle for long lines, so wide code doesn't require horizontal scrolling
- Line numbers in the code/text viewer on both platforms, with fixes to keep them correctly positioned while scrolling on macOS
- Fixed very long single-line files (like minified HTML/JS) rendering blank

**Images**
- Pinch-to-zoom on GitHub and local images — native gesture on iOS, trackpad pinch on macOS
- Fixed images getting stuck oversized with zooming doing nothing
- Fixed handling of oversized GitHub images

**GitHub**
- Create new files of any supported format directly in a connected repo, not just Markdown
- Relative-path images and links inside GitHub-hosted Markdown now resolve correctly
- Word/character counter in the editor toolbar
- Recent commit history now shows in the "What Changed" sheet
- Much clearer diagnostics when a repo can't be opened: Vera now tells you whether it's a stale sign-in token, an installation scoped to only some repos, or something else, instead of a generic "not found"
- Fixed the "Open from GitHub" sheet showing duplicate owner/repository fields after signing in
- GitHub requests now time out after 15 seconds instead of potentially hanging for minutes on a flaky connection
- Error messages in the GitHub connect sheet are now selectable and copyable
- Confirmation prompt before replacing an already-saved GitHub token
- "Remove Repository" reworded to "Disconnect" for clarity

**Sidebar & navigation**
- Tap or click anywhere on a folder row to expand it, not just the small chevron
- Fixed the file tree losing its expanded-folder state after opening a file and navigating back (iOS)
- Fixed a folder-title mismatch in the sidebar

**iOS reliability**
- Fixed a bug where the very first tap to open a file after launch silently failed (a second tap was needed)
- Faster file opening: syntax highlighting now runs on a shared background engine instead of reinitializing per file

**Editor**
- Separate "larger text" / "smaller text" buttons, with a unified default font size across platforms

## v1.2.0

GitHub sign-in now works with one-tap OAuth, no more copy-pasting a token. New: switch branches while browsing a repo, pick a target branch when committing, and commit multiple edited files at once in a single atomic commit. Also fixed several conflict-detection and cross-branch commit bugs.

## v1.1.0

- **GitHub (preview)** — connect a repository with a fine-grained token and browse/read its Markdown directly in Vera. The token talks only to GitHub and lives in your device Keychain.
- **Browse GitHub repos in the sidebar** — connected repos appear as a browsable folder/file tree right in the sidebar (expand to drill into folders and Markdown files, just like an iCloud folder), and **sync across your devices** via iCloud. Opening a repo file gives it a tab alongside your local files. The token stays on each device.
- **Full editor for GitHub files** — repo Markdown opens in the same editor as your local files: view/edit toggle, syntax highlighting, formatting bar, snippets, auto-fix and Focus Mode. Commit straight to the branch or open a pull request. Needs a token with Contents: Read and Write.
- **What changed** — when a repo file has moved on since you last opened it, Vera shows a "What Changed" button and a native diff of the changes — built for skimming the Markdown your agents write.
- **New brand identity** — a refined teal accent throughout, a consistent design system (spacing, radii, typography), and a refreshed onboarding flow.
- **Cleaner, less-cramped UI** — primary actions (New File, Open) are now visible buttons instead of hidden behind a `···` menu; the macOS document toolbar is grouped; folders carry a tinted icon so they read distinctly from files.
- **Focus Mode** — a one-tap distraction-free writing surface that hides the formatting bar and linter, now on iPhone as well as iPad.
- **Flatter formatting bar** — bold, italic, strikethrough, code, heading, list, quote and snippets are all one tap away (no nested menu); every button has an accessibility label.
- **Markdown file icon** — Markdown files now use the Markdown mark (by dcurtis) instead of a generic document icon; dependencies are credited in About.
- **Friendlier empty state** — a clear "No Folder Open" screen with a direct Open Folder action.
- **Reliability & privacy** — fixes a false "Couldn't Load Files" error on launch and moves the folder bookmark into the Keychain.
- **macOS App Sandbox** — the Mac app now runs sandboxed for stronger isolation, with access limited to the folders you pick and outbound network only to GitHub.
- **Consistent code typography** — code uses SF Mono everywhere, and headings/bold in the editor now stay monospaced too (they previously slipped into a different typeface).
- **Clearer sidebar** — the file you're editing is now highlighted in the tree, and files vs folders read at a glance (muted file icons, accent-tinted folders). The local folder section now collapses, and deletion on Mac is right-click only (no more accidental hover trash).
- **Real Focus Mode on Mac** — Focus now hides the tab bar, lint panel and sidebar for a clean, distraction-free editor (previously it only hid the linter).
- **Refreshed Icon Guide** — the icon reference is up to date (GitHub, Markdown files, Focus, commit/diff) and consistent across iPhone, iPad and Mac: it opens from the same overflow (•••) menu everywhere and lists only the icons that actually appear on your platform.
- **Security review** — code and security review with leak, crash and robustness hardening.
- **Code quality** — centralized preference keys and editor font-size config (fixes a macOS font-size default mismatch), dead-code removal and small Swift modernizations.

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
