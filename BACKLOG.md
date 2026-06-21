# Vera — Backlog

See [CHANGELOG.md](CHANGELOG.md) for recent changes.

## Open bugs

*(none)*

---

## Pending

- **GitHub auth: PAT vs GitHub App device flow** — today users mint and paste a fine-grained PAT (Contents + Metadata). If TestFlight feedback says that's too much friction, the no-backend-compatible upgrade is GitHub's OAuth **Device Flow** (enter a code at github.com/login/device — needs only a client ID, no server). Don't build pre-emptively; let onboarding feedback trigger it. Full design in [GITHUB_AUTH_SPEC.md](GITHUB_AUTH_SPEC.md).

---

## Won't fix

- **`^1` footnote/superscript in Atlas** — cannot be delivered
- **Animated V icon** — dropped

---

## Notes

- Reset folder picker: now Keychain-backed via `BookmarkStore` (no longer `defaults delete Vera rootFolderBookmark`); use About → "Reset Vera…".
- macOS App Sandbox **re-enabled 2026-06-21** on GA macOS 26.5.1 (the beta pre-main crash is resolved). Entitlements: app-sandbox, user-selected.read-write, files.bookmarks.app-scope, network.client, ubiquity-kvstore.
- **GitHub PAT scopes** (v1.1.0): fine-grained token needs **Contents** (Read to browse, Read+Write to commit / open PRs) and **Metadata**. Token lives in the Keychain (device-local); the repo list syncs via iCloud KVS.
- VoiceOver testing pending — `accessibilityLabel` added to all icon buttons but never verified with VoiceOver on a real device.
- v1.1.0 GitHub flows (inline browse, open-as-tab, commit/PR/diff, repo sync across devices) ship pending full on-device tap-test with a real Read+Write token.
