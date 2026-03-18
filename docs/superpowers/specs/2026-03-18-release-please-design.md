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
- `chore:`, `docs:`, `test:`, `refactor:` → do not trigger a release on their own, but are included in the next release PR when one exists

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
- **Permissions:** `contents: write`
- **Steps:**
  1. Checkout code with `fetch-depth: 0` (needed for gh-pages worktree operations)
  2. Extract version from tag (`${GITHUB_REF_NAME#v}`)
  3. Build DMG (`make dmg VERSION=$version`)
  4. Download Sparkle tools (same as current)
  5. Sign DMG with Sparkle EdDSA key (same as current)
  6. Wait for GitHub Release to exist (defensive retry loop — release-please creates it moments before the tag push triggers this workflow)
  7. Upload DMG to existing GitHub Release (`gh release upload`)
  8. Update appcast on gh-pages (same as current, using `GITHUB_REF_NAME` for tag/version)
  9. Notify Homebrew tap (same as current, using `GITHUB_REF_NAME` for tag/version)

### Configuration Files

`release-please-config.json`:
```json
{
  "packages": {
    ".": {
      "release-type": "simple",
      "changelog-sections": [
        {"type": "feat", "section": "Features"},
        {"type": "fix", "section": "Bug Fixes"},
        {"type": "refactor", "section": "Refactoring", "hidden": true},
        {"type": "chore", "section": "Miscellaneous", "hidden": true},
        {"type": "docs", "section": "Documentation", "hidden": true},
        {"type": "test", "section": "Tests", "hidden": true}
      ]
    }
  }
}
```

`.release-please-manifest.json`:
```json
{
  ".": "1.0.0"
}
```

The manifest version must match the latest tag (`v1.0.0`).

**Note:** `release-type: simple` causes release-please to create and maintain a `version.txt` file in the repo root. This file is for release-please's bookkeeping. The build pipeline continues to derive the version from git tags.

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

- The `commit-msg` hook accepts release-please's commit format (`chore(main): release X.Y.Z`) — matches `chore` type with `main` scope. (Note: the hook only runs locally; release-please commits are created server-side via the GitHub API.)
- Existing Sparkle auto-update integration is unaffected — appcast still updated on gh-pages
- Homebrew tap notification is unaffected — same dispatch payload
