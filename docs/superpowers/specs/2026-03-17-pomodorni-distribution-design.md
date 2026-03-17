# Pomodorni Distribution Design

## Overview

Distribute the Pomodorni macOS menu bar pomodoro timer as an open-source app via GitHub Releases, Sparkle auto-updates, and a Homebrew tap. Targeting colleagues and developer users initially, with a path to Mac App Store later.

## App Identity

- **Name:** Pomodorni
- **Bundle ID:** `com.ornitech.pomodorni`
- **Copyright:** Copyright 2026 Ornitech
- **Icon:** Tomato-timer-owl hybrid — tomato body in warm red-to-orange gradient, owl eyes and ear tufts, timer stem/dial on top. Clean vector style, legible at small sizes. 1024x1024 master PNG, converted to `.icns` at build time.
- **Minimum macOS:** 14.0 (Sonoma)

## Build & Packaging

### Makefile

Replaces `run.sh` as the primary build interface.


| Target         | Description                                                          |
| -------------- | -------------------------------------------------------------------- |
| `make build`   | Release build via `swift build -c release`                           |
| `make app`     | Assemble `.app` bundle (binary, Info.plist, icon, Sparkle framework) |
| `make dmg`     | Create distributable DMG with app + `/Applications` symlink          |
| `make run`     | Debug build + launch (replaces `run.sh`)                             |
| `make iconset` | Convert 1024x1024 PNG to `.icns` via `iconutil`                      |
| `make clean`   | Remove `.build/`, assembled `.app`, and `.dmg` artifacts             |


### .app Bundle Structure

```
Pomodorni.app/
  Contents/
    Info.plist
    MacOS/
      Pomodorni
    Resources/
      AppIcon.icns
    Frameworks/
      Sparkle.framework
```

### Info.plist Updates

- `CFBundleExecutable` → `Pomodorni`
- `CFBundleName` → "Pomodorni"
- `CFBundleIdentifier` → `com.ornitech.pomodorni`
- `CFBundleVersion` → injected from git tag at build time
- `CFBundleShortVersionString` → same, without `v` prefix
- `CFBundleIconFile` → `AppIcon`
- `SUFeedURL` → `https://ornitech.github.io/pomodorni/appcast.xml`
- `SUPublicEDKey` → Sparkle EdDSA public key
- `NSHumanReadableCopyright` → "Copyright 2026 Ornitech"
- `LSUIElement` → `true` (existing, menu bar only)

### Versioning

Version derived from git tags. Initial release is `v1.0.0`. The CI workflow auto-tags on merge to main:

- Default: patch bump (e.g., `v1.0.0` → `v1.0.1`)
- PR title contains `[minor]`: minor bump (e.g., `v1.0.1` → `v1.1.0`)
- PR title contains `[major]`: major bump (e.g., `v1.1.0` → `v2.0.0`)
- If no tags exist yet, the workflow defaults to `v1.0.0`.

### Code Signing

- **Initial:** Ad-hoc signing (`codesign --force --sign -`). Users right-click → Open on first launch.
- **Later:** Developer ID signing + notarization via Apple Developer Program. Controlled by `SIGNING_IDENTITY` variable in Makefile / CI secret. No structural changes needed.

## Sparkle Auto-Updates

### Integration

- Sparkle v2 is added as a standard SwiftPM package dependency (`.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")`).
- The Makefile `app` target copies `Sparkle.framework` from the SPM build artifacts into `.app/Contents/Frameworks/`.
- `SPUStandardUpdaterController` initialized in `AppDelegate`.
- Sparkle's `sign_update` CLI tool is downloaded from the Sparkle binary release in CI for signing DMGs.

### Update Flow

1. On launch, Sparkle checks `appcast.xml` for newer versions (default: every 24 hours).
2. If an update is found, Sparkle shows its standard update dialog.
3. User can also trigger via "Check for Updates..." in the right-click context menu.

### Appcast

- `appcast.xml` hosted on GitHub Pages (from the `gh-pages` branch of `ornitech/pomodorni`).
- Stable URL: `https://ornitech.github.io/pomodorni/appcast.xml` — this is the `SUFeedURL` baked into Info.plist.
- Each entry contains: version, download URL (DMG on GitHub Releases), EdDSA signature, release notes.
- The release workflow commits the updated `appcast.xml` to the `gh-pages` branch.

### Security

- Sparkle v2 uses EdDSA (ed25519) for update signing.
- Keypair generated once via Sparkle's `generate_keys` tool.
- Private key stored as `SPARKLE_PRIVATE_KEY` GitHub Actions secret.
- Public key embedded in Info.plist as `SUPublicEDKey`.

### Settings

- "Check for updates automatically" toggle in Settings view, wired to Sparkle's `automaticallyChecksForUpdates`.

## GitHub Actions CI/CD

### CI Workflow (`.github/workflows/ci.yml`)

Runs on every push and pull request:

1. Check out code
2. `swift build` on `macos-14` runner
3. `swift test`

### Release Workflow (`.github/workflows/release.yml`)

Triggered on merge to main branch:

1. Determine version bump from PR title (`[minor]`, `[major]`, or default patch)
2. Find latest git tag, calculate next version
3. Create and push new git tag
4. `swift build -c release`
5. Assemble `.app` bundle (binary, Info.plist with injected version, icon, Sparkle framework)
6. Ad-hoc codesign (or Developer ID if secret is present)
7. Create DMG via `hdiutil`
8. Sign DMG with Sparkle's `sign_update` tool using EdDSA key (produces signature for appcast)
9. Generate/update `appcast.xml` entry with version, DMG URL, and EdDSA signature
10. Commit updated `appcast.xml` to `gh-pages` branch
11. Create GitHub Release with DMG attached
12. Dispatch `repository_dispatch` to `ornitech/homebrew-tap` to update the cask

### Secrets Required


| Secret                     | Purpose                                                        |
| -------------------------- | -------------------------------------------------------------- |
| `SPARKLE_PRIVATE_KEY`      | EdDSA private key for signing updates                          |
| `HOMEBREW_TAP_TOKEN`       | PAT with repo scope for dispatching to `ornitech/homebrew-tap` |
| `DEVELOPER_ID_CERTIFICATE` | (Optional, later) Base64 .p12 for Developer ID signing         |
| `DEVELOPER_ID_PASSWORD`    | (Optional, later) Password for the .p12                        |


## Homebrew Tap

### Repository

`ornitech/homebrew-tap` — a public repo containing Homebrew cask formulae for Ornitech apps.

### Install Commands

```bash
brew tap ornitech/tap
brew install --cask pomodorni
```

Or one-liner: `brew install ornitech/tap/pomodorni`

### Cask Formula

`Casks/pomodorni.rb` in the `homebrew-tap` repo. Contains:

- App name and version
- DMG download URL (GitHub Releases)
- SHA256 hash of the DMG
- App artifact name

### Auto-Update

The release workflow in `ornitech/pomodorni` dispatches a `repository_dispatch` event to `ornitech/homebrew-tap`. A workflow in the tap repo receives this, updates the cask version and SHA256, and auto-commits.

## App Icon

- **Design:** Tomato-timer-owl hybrid. Tomato body in warm red-to-orange gradient, owl eyes peering out, small ear tufts, timer stem/dial on top. Clean vector style, legible at 16x16.
- **Source:** `Pomodorni/Assets/AppIcon.png` (1024x1024)
- **Build:** `make iconset` converts to `.icns` via `sips` + `iconutil`
- **Manual task:** User provides the 1024x1024 PNG.

## Repo Conventions

Added to CLAUDE.md:

- **Conventional commits:** All commits use conventional commit format (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`)
- **PR tagging:** All PRs get appropriate labels (`patch`, `minor`, `major`, `docs`, `chore`) and descriptive titles

## Migration Steps

The existing project needs renaming and restructuring:

- Rename source directory `Pomodoro/` → `Pomodorni/`
- Rename test directory `PomodoroTests/` → `PomodorniTests/`
- Rename snapshot test directory `PomodoroSnapshotTests/` → `PomodorniSnapshotTests/`
- Update `Package.swift`:
  - Rename executable target from `"Pomodoro"` to `"Pomodorni"`
  - Rename test targets from `"PomodoroTests"` / `"PomodoroSnapshotTests"` to `"PomodorniTests"` / `"PomodorniSnapshotTests"`
  - Update all `path:` values to match new directory names
  - Update `dependencies: ["Pomodoro"]` → `dependencies: ["Pomodorni"]` in test targets
  - Update product name in `products:` array
- Update `Info.plist`: new bundle ID, name, executable name, Sparkle keys
- Update user-visible strings: "Quit Pomodoro" → "Quit Pomodorni", accessibility descriptions
- Replace `run.sh` with `Makefile`
- Update `.gitignore` with `*.dmg`, `*.icns` (generated), assembled `.app` artifacts

## Future Path

- **Developer ID signing + notarization:** Eliminates Gatekeeper warnings. Requires Apple Developer Program ($99/year). Drop-in via CI secret.
- **Mac App Store:** If user feedback warrants it. Separate build configuration, no Sparkle (App Store handles updates).
- **Official homebrew-cask:** Submit to `homebrew/homebrew-cask` once the app has enough traction for `brew install --cask pomodorni`.

