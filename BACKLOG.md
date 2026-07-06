# Vera — Backlog

See [CHANGELOG.md](CHANGELOG.md) for recent changes.

## Open bugs

*(none)*

---

## Pending

- **App Store Connect submission (iOS 1.0)** — the missing app-icon on the ASC Apps grid is *not* an asset defect (icon is 1024×1024, RGB, no alpha, no baked rounded corners, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` set). The grid shows the generic wireframe because **no build is attached to the 1.0 version**. Fix: on the version page → Build section → add a processed build → Save; the grid thumbnail then populates from that build (same step needed for Mira). Marketing copy (promotional text, description, keywords) was drafted in Miguel's voice this session — paste into ASC. Optional asset polish (deferred): dark/tinted icon variants are byte-identical copies of the light icon, and the PNG carries no embedded sRGB profile.
- **GitHub Device Flow: explain the post-approval install step** — Device Flow sign-in (`86abb0a`, client ID wired `408de80`) authorizes the user but does not install the GitHub App on any repo; the user must separately install it via `github.com/settings/apps/<slug>/installations` before Vera can read their repos, or API calls 404. The in-app sign-in UI doesn't explain this second step yet — confirmed confusing during manual testing 2026-07-06 (hit a live 404 until the app was installed). Add copy in the sign-in sheet or a follow-up screen telling the user GitHub will also ask them to install the app on the repos they want Vera to access.
- **`DEVELOPMENT_TEAM` Team ID in `project.pbxproj`** — reviewed 2026-07-06 ahead of making the repo public: `HTVGRBVW58` is a Team ID (not a credential, grants no access) and is already exposed via every shipped IPA/TestFlight build/App Store Connect metadata. Accepted as non-sensitive; no git history rewrite planned.
- **Accessibility — device pass + Nutrition Label** — code remediation F1–F6 and F8 done (labels, Dynamic Type for mono text, decorative-icon hiding, selection traits, Reduce Motion); see [ACCESSIBILITY_SPEC.md](ACCESSIBILITY_SPEC.md). F5 left as-is, F7 (preview heading/table VoiceOver structure) deferred. **Pending:** on-device VoiceOver + Dynamic Type pass on the core flows, then fill the App Store Connect Accessibility Nutrition Labels (VoiceOver, Larger Text, Voice Control, Reduced Motion, Differentiate Without Color, Sufficient Contrast, Dark Interface).

---

## Won't fix

- **`^1` footnote/superscript in Atlas** — cannot be delivered
- **Animated V icon** — dropped

---

## Notes

- **Preferences live in `Defaults.swift`** (added 2026-06-22) — single source of truth for every `UserDefaults`/`@AppStorage` key (`Defaults.Key.*`) and the editor font-size config (`Defaults.FontSize`: 12–32 bounds, step, platform default + `increased/decreased`). Add new prefs there, not as inline string literals. The font-size default is 17 on macOS / 20 on iOS — fixed a prior mismatch where `DocumentView` hardcoded 20 on both, disagreeing with the editor's 17 on macOS; this feeds ACCESSIBILITY_SPEC F2 (the macOS control + iOS `monoScale` share one set of numbers).
- **Root security-scoped access is balanced via `rootAccessURL`** in `FileTreeViewModel` (security review 2026-06-22) — acquired idempotently (once per root, released on root change), and released in `resetState`/`releaseAllAccess`. Don't re-add a `deinit` to release it: Swift 6 forbids a nonisolated `deinit` touching `@MainActor` state, and this single app-lifetime VM only deallocs at process exit. Don't re-introduce per-load `startAccessingSecurityScopedResource` (that was the leak).
- **macOS editor caches the selection as an `NSRange`** (`HighlightingTextView` Coordinator) — it's clamped via `validRange(_:in:)` and cleared via `invalidateCachedRange()` after external text swaps. Keep both: a stale range here was an `NSRangeException` crash on format actions after autosave reload / auto-fix.
- Reset folder picker: now Keychain-backed via `BookmarkStore` (no longer `defaults delete Vera rootFolderBookmark`); use About → "Reset Vera…".
- macOS App Sandbox **re-enabled 2026-06-21** on GA macOS 26.5.1 (the beta pre-main crash is resolved). Entitlements: app-sandbox, user-selected.read-write, files.bookmarks.app-scope, network.client, ubiquity-kvstore.
- **GitHub PAT scopes** (v1.1.0): fine-grained token needs **Contents** (Read to browse, Read+Write to commit / open PRs) and **Metadata**. Token lives in the Keychain (device-local); the repo list syncs via iCloud KVS.
- VoiceOver testing pending — `accessibilityLabel` added to all icon buttons but never verified with VoiceOver on a real device.
- v1.1.0 GitHub flows (inline browse, open-as-tab, commit/PR/diff, repo sync across devices) ship pending full on-device tap-test with a real Read+Write token.
