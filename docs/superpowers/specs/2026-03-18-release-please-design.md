# Release-Please Integration Design

## Goal

Replace the automatic release-on-every-push workflow with a release-please flow where:
1. Conventional commits accumulate on main
2. release-please opens/updates a release PR with CHANGELOG and version bump
3. Manually merging the release PR creates the tag and GitHub Release
4. A tag-triggered workflow builds, signs, and publishes the DMG

## Versioning Rules

Determined by release-please from conventional commits:
- `feat!:` (or any `type!:`) → major
- `feat:` → minor
- `fix:` → patch
- `chore:`, `docs:`, `test:`, `refactor:` → no release (ignored)

## Workflow Architecture

### Workflow 1: `release-please.yml` (new)

- **Trigger:** `push` to `main`
- **Runs on:** `ubuntu-latest` (no macOS needed — no build step)
- **Action:** `googleapis/release-please-action@v4` with `release-type: simple`
- **Behavior:**
  - On regular pushes: creates or updates a release PR with CHANGELOG entries and version bump
  - When the release PR is merged: creates a git tag (`vX.Y.Z`) and GitHub Release with CHANGELOG body
- **Permissions:** `contents: write`, `pull-requests: write`

### Workflow 2: `release.yml` (rewritten)

- **Trigger:** `push` of tags matching `v*`
- **Runs on:** `macos-15`
- **Steps:**
  1. Checkout code
  2. Extract version from tag (`${GITHUB_REF_NAME#v}`)
  3. Build DMG (`make dmg VERSION=$version`)
  4. Download Sparkle tools (same as current)
  5. Sign DMG with Sparkle EdDSA key (same as current)
  6. Upload DMG to existing GitHub Release (`gh release upload`)
  7. Update appcast on gh-pages (same as current)
  8. Notify Homebrew tap (same as current)

### Configuration Files

- `release-please-config.json` — release-please configuration (release type, CHANGELOG settings)
- `.release-please-manifest.json` — tracks current version

## What Is Removed

- Version bump shell logic (lines 22-55 of current `release.yml`) — release-please handles this
- `[skip-release]` check — release-please naturally skips non-feat/fix commits
- `softprops/action-gh-release` step — release-please creates the GitHub Release; we just upload the DMG asset
- Tag creation step — release-please creates the tag

## What Is Preserved (Unchanged Logic)

- DMG build via `make dmg`
- Sparkle EdDSA signing
- Appcast XML update on gh-pages
- Homebrew tap notification via repository dispatch

## Compatibility

- The `commit-msg` hook accepts release-please's commit format (`chore(main): release X.Y.Z`) — matches `chore` type with `main` scope
- Existing Sparkle auto-update integration is unaffected — appcast still updated on gh-pages
- Homebrew tap notification is unaffected — same dispatch payload
