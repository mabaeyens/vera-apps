# Vera — Backlog

## Phase status
- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** 🔜 In progress

---

## Phase 3 — Upcoming (prioritized)

1. **iOS TestFlight distribution** — archive iOS target, upload to App Store Connect, invite testers
2. **Markdown cheat sheet** — built-in reference sheet bundled as a `.md` resource, rendered by Vera itself; accessible via toolbar button on both platforms
3. **Atlas drawer** — bottom sheet (iOS) / trailing panel (macOS) with tap-to-insert Markdown snippets
4. **Syntax highlighting** — `SyntaxHighlightingEditor` using Highlightr (UIViewRepresentable wrapping UITextView)
5. **Onboarding view** — first-launch explanation of iCloud access and folder picker
6. **Auto-save robustness** — NSFileVersion conflict handling
7. **App icon dark/tinted variants** — dark mode and tinted versions of AppIcon for iOS 18+

---

## Known bugs

*(none)*

---

## Notes

- Bundle ID: `com.mab.Vera` — UserDefaults domain is `Vera` (not `com.mab.Vera`)
- App Sandbox must be OFF on macOS target (crashes pre-main on macOS 26 beta with iCloud entitlements)
- Root folder stored as security-scoped bookmark in `UserDefaults` key `rootFolderBookmark`
- To reset folder picker during testing: `defaults delete Vera rootFolderBookmark`
- MarkdownUI SPM: `https://github.com/gonzalezreal/swift-markdown-ui`
- Highlightr SPM: `https://github.com/raspu/Highlightr`
- Smart Anchor v1 uses proportional approximation; upgrade to TextKit 2 exact mapping only if user reports it as jarring
- iOS untested — needs TestFlight run before Phase 3 features
