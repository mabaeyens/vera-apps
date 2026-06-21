# Spec — GitHub authentication: PAT vs. device-flow sign-in

**Status:** Proposed (do not build yet). Triggered by TestFlight onboarding feedback.
**Author:** Miguel A. Baeyens · **Date:** 2026-06-21 · **Target:** post-1.1.0

## Problem

Vera's GitHub integration (1.1.0) authenticates with a **fine-grained Personal Access
Token** the user creates on github.com and pastes into the connect sheet. It works and
keeps Vera backend-free, but minting a fine-grained PAT is a multi-step chore:
github.com → Settings → Developer settings → Fine-grained tokens → pick repos → pick
Contents + Metadata → set expiry → copy → paste. For a tester or a casual user that's a
lot of friction before they see a single file, and an expired token means doing it again.

The question this spec answers: **can we offer a one-tap "Sign in with GitHub" without
adding a backend or a stored client secret** — and is it worth it?

## Constraints (non-negotiable, from positioning)

1. **No backend.** Vera is a native client only. No server, nothing to host, no secret
   we ship in the binary (a secret in a distributed app is not a secret).
2. **Least privilege.** Today's PAT asks only for Contents (read, or read+write) and
   Metadata. Don't regress to broad, all-or-nothing scopes if avoidable.
3. **Token stays on device.** Stored in the Keychain via `CredentialStore`, never synced
   (not iCloud, not anywhere). Unchanged by this spec.
4. **Privacy posture unchanged.** Vera talks only to `api.github.com` / `github.com`,
   directly, on the user's behalf.

## Options

### A. Status quo — fine-grained PAT (paste)
- **Pros:** zero registration on our side; finest-grained permissions; no token-refresh
  machinery; already shipped.
- **Cons:** highest user friction; users over-scope or under-scope; expiry = re-do.

### B. OAuth Device Flow + **GitHub App** (recommended)
The OAuth Device Authorization Flow: the app shows a short code, the user enters it at
`github.com/login/device` in any browser, approves, and the app polls for a token. The
device flow for a GitHub App needs **only the client ID** — no client secret — so it fits
the no-backend rule.
- **Pros:** one-tap-ish UX (show code, open browser, done); fine-grained per-repo
  permissions preserved (Contents + Metadata); the modern, GitHub-recommended app type;
  client ID is not a secret, safe to ship.
- **Cons:** GitHub Apps must be **installed** on the user's account/selected repos, so the
  flow has an install step the first time; user-to-server tokens **expire** unless
  expiration is turned off, and refreshing an expired token needs the client secret
  (which we can't ship). Mitigation: **disable user token expiration** on the App so the
  user-to-server token is long-lived and no secret-bearing refresh is ever needed.

### C. OAuth Device Flow + **OAuth App**
Same device flow, but an OAuth App grants classic scopes instead of fine-grained
permissions, and needs no installation step.
- **Pros:** simplest to implement (no install flow); device-flow token doesn't expire by
  default; only a client ID needed.
- **Cons:** the `repo` scope is **all-or-nothing** — full control of all the user's
  private repos. That's a real regression from the fine-grained PAT and against the
  least-privilege constraint. GitHub also steers new integrations toward GitHub Apps.

### D. Full OAuth web (authorization-code) flow — **rejected**
Requires exchanging the code for a token using the client **secret**, i.e. a backend.
Violates constraint 1. Not considered further.

## Recommendation

**Option B — GitHub App + Device Flow, with user-token expiration disabled** — kept
alongside Option A as an "advanced" fallback. It's the only option that gives a smooth
sign-in *and* keeps both the no-backend and least-privilege constraints. Accept the
one-time installation step as the price of fine-grained permissions.

If, at implementation time, the GitHub App installation step proves too clunky for the
target user, fall back to **Option C** and document the broader scope honestly in the
connect UI and PRIVACY.md.

## Design (Option B)

### One-time setup (us, not code)
1. Register a **GitHub App** (public) under the Vera org/account. Permissions:
   **Repository → Contents: Read and write**, **Metadata: Read-only**. No webhook.
2. Enable **"Request user authorization (OAuth) during installation"** and **Device
   Flow**; **disable** "Expire user authorization tokens".
3. Record the **client ID** — ship it in the app (it is not a secret).

### Runtime flow (client)
1. `POST https://github.com/login/device/code` with `client_id` → returns
   `device_code`, `user_code`, `verification_uri`, `expires_in`, `interval`.
2. Show a sheet: the `user_code` in large mono text, a "Copy & Open GitHub" button that
   copies the code and opens `verification_uri`, and a spinner ("Waiting for approval…").
3. Poll `POST https://github.com/login/oauth/access_token` with
   `grant_type=urn:ietf:params:oauth:grant-type:device_code`, `device_code`, `client_id`
   every `interval` seconds. Handle `authorization_pending` (keep polling), `slow_down`
   (increase interval), `expired_token` (restart), `access_denied` (cancel).
4. On success store the returned `access_token` in `CredentialStore` — **same slot the
   PAT uses today**, so everything downstream is unchanged.
5. If the user hasn't installed the App on the target repo, the first API call returns
   404/403; detect this and deep-link to the App's installation page to pick repos.

### Blast radius
Deliberately small. `GitHubClient` already takes an opaque bearer token; it doesn't care
whether it came from a PAT or the device flow. `CredentialStore` is unchanged. The only
new surface is a `GitHubDeviceAuth` helper (the two HTTP calls + polling) and a
`DeviceAuthSheet` view. The existing connect sheet keeps a "Use a token instead"
(advanced) path for power users and for anyone who prefers a PAT.

### Token storage & lifecycle
- Stored in the Keychain, device-local, never synced (unchanged).
- With expiration disabled, no refresh logic is needed; if GitHub ever revokes or the
  user uninstalls the App, calls 401 → surface "reconnect" and rerun the device flow.
- Sign-out clears the Keychain entry (already supported for the PAT).

## UX copy (draft)
- Primary button on the connect sheet: **"Sign in with GitHub"** (device flow).
- Secondary, smaller: **"Use a personal access token instead"** (today's flow).
- Device sheet: "Open github.com/login/device and enter this code", the code, one button.

## Open questions / risks
- **Installation friction.** GitHub Apps need installation per repo/account; verify the
  real-world tap count before committing. If it's bad, fall back to Option C.
- **Multiple accounts / orgs.** A user with personal + org repos may need the App
  installed in several places. Out of scope for v1 of this feature; document the limit.
- **Endpoint/behavior drift.** Confirm the device-flow endpoints, error codes, and the
  "disable expiration" toggle against current GitHub docs at implementation time — the
  details above reflect the API as of this writing and GitHub iterates.
- **Rate limits.** Unchanged (per-user), but the polling loop must honor `interval` /
  `slow_down` to avoid secondary rate limits.

## Out of scope
- Any backend or hosted component.
- GitHub Marketplace listing.
- Replacing or removing the PAT path (it stays as the advanced option).
- Enterprise Server auth.

## Decision trigger
Build this **only** when TestFlight/beta feedback shows the PAT step is a real drop-off.
Until then, the PAT flow (Option A) stands and this spec waits.
