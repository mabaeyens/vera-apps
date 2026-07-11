# CLAUDE.md

**Vera** — iOS/macOS native git-aware file editor (Markdown, code, JSON/YAML, text — any file it can open is editable, not just Markdown). Swift 6, SwiftUI. No vault — filesystem is the data model.

## Constraints

- `@MainActor` on all ViewModels (Swift 6).
- `async/await` for all file I/O; wrap `FileManager` calls in `Task`.
- No force-unwraps in production paths.
- App Sandbox is **enabled** on the macOS target (re-enabled 2026-06-21 on GA macOS 26.5.1; the old pre-main crash was a macOS 26 *beta* bug, now resolved). Entitlements live in `Vera/Vera/Vera.entitlements`: app-sandbox, user-selected.read-write, files.bookmarks.app-scope (security-scoped folder bookmark), network.client (GitHub API), ubiquity-kvstore (GitHub repo-list sync), plus the iCloud container. Keep these when touching entitlements — dropping network.client breaks GitHub, dropping ubiquity-kvstore breaks repo sync.
- **GitHub credentials:** the fine-grained PAT lives only in the Keychain via `CredentialStore` — never in `UserDefaults`, never synced (not iCloud, not anywhere). The saved-repo list lives in `NSUbiquitousKeyValueStore` (`RepoListStore`) and syncs via iCloud KVS — it holds only `owner/repo`, never the token. Never write the token to KVS or any synced/committed store. The folder bookmark is Keychain-backed via `BookmarkStore`.
- `PrivacyInfo.xcprivacy` exists at `Vera/Vera/PrivacyInfo.xcprivacy` — do not recreate it. The target uses a synchronized root group, so it is bundled automatically (confirmed in built `Vera.app/Contents/Resources/`); no manual Xcode step needed.
