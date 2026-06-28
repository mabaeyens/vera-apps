# Spec — GitHub feature roadmap

**Author:** Miguel A. Baeyens · **Date:** 2026-06-27  
**Scope:** Six features to bring Vera to full GitHub-native editor status.  
Implement one at a time in the order listed; each builds on the previous.

---

## Feature 1 — OAuth Device Flow (easier sign-in)

**Status:** Proposed; trigger is TestFlight onboarding drop-off data.  
**Full spec:** See [GITHUB_AUTH_SPEC.md](GITHUB_AUTH_SPEC.md) — design, API calls, blast
radius, and open questions are fully documented there.

**Summary:** Replace the copy-paste PAT flow with GitHub's OAuth Device Flow (user enters
a short code at `github.com/login/device`). Needs only a client ID — no backend, no
secret shipped. The stored token goes into the same `CredentialStore` Keychain slot, so
all downstream code is unchanged. The PAT path stays as an "advanced" option.

**Don't build until:** TestFlight data shows the PAT step is a real drop-off point.

---

## Feature 2 — Branch picker in the commit sheet

**Status:** Proposed.

### Problem

`GitHubCommitSheet` always commits to whatever branch the file was opened from
(`GitHubBrowserModel.branch`), which is always `defaultBranch`. There is no way to:
- Commit to an existing feature branch that's already open for review.
- Open a PR that targets a branch other than the default.

The segmented Commit / Pull Request picker already works correctly; what's missing is
branch selection.

### Design

Add a branch picker row to the commit form (below the Commit / PR picker). It shows the
current branch pre-selected and lets the user pick any existing branch from the repo.

#### In `.commit` mode
The picker selects the branch to commit to directly. The footer copy updates to read
"Commits directly to '{selectedBranch}'."

#### In `.pullRequest` mode
The picker selects the **base** branch for the PR (the branch the PR will merge into).
The new branch is created off `defaultBranch` as today; the PR's `base` field is set to
the picker selection. Footer: "Creates a branch off '{defaultBranch}' and opens a pull
request into '{selectedBranch}'."

### API

```
GET /repos/{owner}/{repo}/branches
→ [{ "name": "main" }, { "name": "feature/x" }, …]
```

Fetch once when the sheet appears; cache in `@State`. Show a spinner in the picker row
while loading. If the fetch fails, fall back to the current branch only (no picker).

### Changes

- **`GitHubClient`**: add `func branches() async throws -> [String]`.
- **`GitHubCommitSheet`**: add `branches: [String]` state; picker row in the form;
  pass the selected branch into the `commit` closure (new `targetBranch: String` param).
- **`DocumentView`** (caller of `GitHubCommitSheet`): update the `commit` closure
  signature to accept `targetBranch`.

### Edge cases

- Repo with hundreds of branches: the GitHub API returns up to 30 per page by default.
  Add `?per_page=100` and accept the first page (100 branches) — enough for any normal
  repo without pagination complexity.
- If fetching branches fails, collapse the picker and commit to the current branch
  silently (same behaviour as today).
- Branch names that contain `/` (e.g. `feature/my-thing`): already handled by
  `GitHubClient.encode(path:)`.

---

## Feature 3 — Pull / refresh (detect remote changes)

**Status:** Proposed.

### Problem

Vera has no awareness of remote changes. If another contributor commits to a file after
Vera opened it, the user is editing a stale copy. Committing it writes a stale `sha` to
the GitHub API — GitHub rejects with `409 Conflict` (sha mismatch), which currently
surfaces as a raw `badResponse(409)` error with no recovery path.

### Design

#### Stale-detection on commit

When `commitFile` fails with a 409, catch it specifically in `DocumentView`'s commit
closure and present a recovery sheet instead of a generic error:

> **"The file changed on GitHub"**  
> Someone else committed since you opened this file. View the diff or overwrite their
> changes.  
> [View Diff] [Overwrite] [Cancel]

- **View Diff**: fetch the latest version from GitHub and push it into `GitHubDiffView`
  showing their version vs. the user's current editor text. The user resolves manually,
  then commits again.
- **Overwrite**: fetch the current blob SHA and re-commit with the user's text (force
  overwrite).

#### Periodic freshness indicator (optional, deferred)

A secondary goal (v2 of this feature): when a GitHub file tab is in the foreground, poll
`latestCommit(path:)` every 60 seconds and show a non-blocking banner "Updated on GitHub
— tap to refresh" if the SHA changed. Don't auto-refresh (would discard the user's
unsaved edits). Defer this until the core conflict resolution above is shipped.

### API

No new endpoints. The `fileVersion(path:ref:)` method already fetches the latest SHA
and text. The `diff(path:from:to:)` method already diffs two SHAs.

### Changes

- **`DocumentView`**: catch `GitHubError.badResponse(409)` in the commit closure;
  present a `ConflictSheet` (new view).
- **`ConflictSheet`** (new): shows options above. "Overwrite" re-calls `fileVersion`
  to get the current SHA, then retries `commitFile`.
- **`GitHubClient`**: add `case conflict` to `GitHubError`, mapped from status 409.

### Edge cases

- Network failure during the "Overwrite" re-fetch: surface the error and leave the user
  in the editor (don't lose their text).
- Very large diff (GitHub omits the patch for diffs > 20k lines): fall back to showing
  "The file changed but the diff is too large to display. Overwrite or cancel."

---

## Feature 4 — Multi-file commits

**Status:** Proposed.

### Problem

`commitFile` writes one file per GitHub API call, one commit per file. There is no way
to atomically commit multiple edited files. This matters when a single logical change
touches several files (e.g. updating an index and the file it references).

### Design

A "Commit all changes" sheet, accessible from the repo view (GitHub sidebar tab) when
more than one file has unsaved edits. It shows a checklist of changed files (pre-ticked),
a single commit message field, and the same Commit / PR segmented picker.

The Vera edit model today has no cross-file dirty tracking — `DocumentViewModel`/
`EditorViewModel` track dirty state per-tab. The multi-file commit needs a list of
`(path, text, sha)` tuples for the files the user checks.

#### GitHub API: Git Data (tree + commit) approach

Single-file `PUT /repos/{o}/{r}/contents/{path}` creates one commit per call. For multi-
file, use the Git Data API:

```
1. GET  /repos/{o}/{r}/git/ref/heads/{branch}   → base commit SHA
2. GET  /repos/{o}/{r}/git/commits/{sha}         → base tree SHA
3. POST /repos/{o}/{r}/git/trees                 → new tree with all changed blobs
     body: { base_tree: <treesha>, tree: [{ path, mode:"100644", type:"blob", content }] }
     → new tree SHA
4. POST /repos/{o}/{r}/git/commits               → new commit
     body: { message, tree: <newTreeSHA>, parents: [<baseCommitSHA>] }
     → new commit SHA
5. PATCH /repos/{o}/{r}/git/refs/heads/{branch}  → advance the branch ref
     body: { sha: <newCommitSHA> }
```

For the PR path, steps 1–4 are done on a new branch (created via `createBranch` after
step 1) and step 5 advances the new branch. Then `openPullRequest` as today.

#### Dirty-state aggregation

Add a lightweight `GitHubDraftStore` (in-memory, `@Observable`) that any `DocumentView`
editing a GitHub file registers its `(ref, currentText, blobSHA)` into when text changes.
The sidebar repo tab reads this store to know how many files are dirty and to populate
the checklist.

### Changes

- **`GitHubClient`**: add `func commitFiles(_ files: [(path: String, text: String)], message: String, branch: String, baseSHA: String, baseTreeSHA: String) async throws -> String?` using the Git Data flow above. Also add `func treeSHA(commitSHA: String) async throws -> String`.
- **`GitHubDraftStore`** (new, `@MainActor @Observable`): dictionary of
  `GitHubFileRef → (text: String, blobSHA: String)`. Injected into the environment.
- **`DocumentView`**: register / deregister drafts in `GitHubDraftStore` when a GitHub
  file is edited.
- **`MultiFileCommitSheet`** (new): checklist of dirty files, message field, Commit / PR
  picker, same UX shell as `GitHubCommitSheet`.
- **`GitHubBrowserView`** or sidebar tab: "Commit N files" button when
  `GitHubDraftStore` has entries for the current repo.

### Edge cases

- One file in the multi-commit fails validation (e.g. path conflict): GitHub rejects the
  tree POST; surface the error without partial commits (the Git Data API is atomic — all
  or nothing at the tree level).
- Race: another contributor commits between step 1 and step 5 → step 5 returns 422.
  Recover the same way as Feature 3 (re-fetch, retry or overwrite).
- Single-file path: if only one file is checked, fall back to the existing
  single-file `commitFile` (simpler, fewer API calls).

---

## Feature 5 — Branch switching

**Status:** Proposed.

### Problem

`GitHubBrowserModel.connect()` always fetches files from `defaultBranch` and stores that
branch in `model.branch`. Every file opened, every commit, every diff is pinned to the
default branch. There is no way to browse, read, or edit files on a feature branch.

### Design

Add a branch picker to `GitHubBrowserView`'s file list toolbar. Tapping it shows a sheet
or menu with all branches; selecting one re-fetches `markdownFiles(branch:)` and updates
`model.branch`. All subsequent file opens and commits use the new branch.

#### Toolbar placement

On iOS: a `ToolbarItem` in the file list navigation bar, showing the current branch name
with a chevron. Tapping opens a half-height sheet (`presentationDetents([.medium])`).

On macOS: a `Menu` button in the toolbar showing `"Branch: main ▾"`.

#### Branch list sheet / menu

A searchable list of branch names. The current branch has a checkmark. Selecting a branch
dismisses and re-fetches.

```
GET /repos/{owner}/{repo}/branches?per_page=100
→ [{ "name": "main" }, { "name": "feature/my-thing" }, …]
```

#### State changes

- `GitHubBrowserModel`: add `func switchBranch(_ name: String) async` — sets `branch`,
  sets `isLoading`, re-fetches `markdownFiles(branch:)`, clears `items` on error.
- Files opened from a non-default branch carry that branch in `GitHubFileRef.branch`,
  so `DocumentView`'s commit sheet defaults to the correct branch automatically.

### Changes

- **`GitHubClient`**: add `func branches() async throws -> [String]` (same as Feature 2;
  implement once, share).
- **`GitHubBrowserModel`**: add `func switchBranch(_ name: String) async`.
- **`GitHubBrowserView`**: branch picker toolbar button + `BranchPickerSheet` (new, ~40
  lines: searchable `List` of branch names).

### Edge cases

- Switching branches while a file is open in an editor tab: the tab keeps its original
  branch (stored in `GitHubFileRef`); switching the browser branch does not affect open
  tabs.
- `GitHubDraftStore` (Feature 4): drafts are keyed by `GitHubFileRef` which includes the
  branch, so dirty state is per-branch and does not bleed across branches.
- Repos with no branches other than default: the picker shows one entry; switching is a
  no-op.

---

## Feature 6 — Search within a GitHub repo

**Status:** Proposed.

### Problem

`GitHubBrowserView` shows a flat list of all `.md` files sorted by path. For repos with
dozens or hundreds of files, there is no way to find a specific file or phrase without
scrolling the entire list.

### Design

Two search modes, accessible via a `searchable` modifier on the file list:

#### Mode A — filename search (client-side, instant)
Filter the already-loaded `model.items` array by `item.path.localizedCaseInsensitiveContains(query)`.
No API call. Happens as the user types. This is the default mode.

#### Mode B — content search (GitHub Code Search API, on demand)
A "Search file contents" toggle below the search bar (or a scoped button labeled
"Search in content"). Triggers:

```
GET /search/code?q={query}+repo:{owner}/{repo}&per_page=30
```

Returns files whose contents match the query. Results are shown as a separate section
below any filename matches. Each row shows the file path; tapping opens it in the editor.

**Rate limit:** The Code Search API is limited to 10 requests/minute for authenticated
users. Show results only after the user pauses typing for 800 ms (debounce). If a 403/429
is received, show "Search rate limit reached — try again in a moment" and suppress
further calls for 60 s.

#### No full-text preview in results

The Code Search API returns `text_matches` fragments only when the `Accept` header
includes `application/vnd.github.text-match+json`. Add that header for code search
requests and show the matched fragment (truncated to ~120 chars) as the row's subtitle.

### API

- Filename search: no API call (filter `model.items`).
- Content search: `GET /search/code?q={query}+repo:{owner}/{repo}&per_page=30`
  with `Accept: application/vnd.github.text-match+json`.

### Changes

- **`GitHubClient`**: add  
  ```swift
  struct CodeSearchResult: Identifiable { let path: String; let fragment: String?; var id: String { path } }
  func searchCode(query: String) async throws -> [CodeSearchResult]
  ```
  Include the text-match header on this request only.
- **`GitHubBrowserModel`**: add `searchResults: [CodeSearchResult]`, `isSearching: Bool`,
  `func searchCode(_ query: String) async`.
- **`GitHubBrowserView`**: add `.searchable(text: $model.searchQuery)`;
  split `fileList` into a filtered section (filename matches) + async content-search
  section; debounce content search with `.task(id: model.searchQuery)` + `Task.sleep`.

### Edge cases

- Empty query: clear both sections; show the full file list.
- File appears in both filename and content results: de-duplicate by path.
- Code Search is unavailable on GitHub Enterprise Server (different endpoint): out of
  scope for this spec.
- The query contains characters that need URL encoding (spaces, quotes): use
  `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` (already implemented
  as `encode(query:)` in `GitHubClient`).

---

## Implementation order

| # | Feature | Prerequisite |
|---|---------|-------------|
| 1 | OAuth Device Flow | None (wait for TestFlight data) |
| 2 | Branch picker in commit sheet | None |
| 3 | Pull / refresh + conflict recovery | None |
| 4 | Multi-file commits | 2 (reuses branch picker logic) |
| 5 | Branch switching | 2 (reuses `branches()` API method) |
| 6 | Search | 5 (best after branch context is stable) |

Recommended starting point: **Feature 3** (pull/refresh) — it fixes an existing bug
(409 on stale SHA) and has the smallest blast radius. Feature 2 (branch picker) is a
close second.
