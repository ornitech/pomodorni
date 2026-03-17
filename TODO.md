# Manual Setup Tasks

Things you need to do that can't be automated from the CLI.

## Required Before First Release

- [ ] **Create GitHub organization "ornitech"** — https://github.com/organizations/new (free)
- [ ] **Create repo `ornitech/pomodorni`** — transfer or push the pomodoro project here
- [ ] **Create repo `ornitech/homebrew-tap`** — empty repo for the Homebrew tap
- [ ] **Generate Sparkle EdDSA keypair** — run the generate_keys tool after Sparkle is integrated (I'll add instructions)
- [ ] **Add GitHub Actions secrets:**
  - `SPARKLE_PRIVATE_KEY` — Sparkle EdDSA private key (from generate_keys tool)
  - `HOMEBREW_TAP_TOKEN` — GitHub PAT with `repo` scope, for dispatching to `ornitech/homebrew-tap`
- [ ] **Enable GitHub Pages** on `ornitech/pomodorni` — deploy from `gh-pages` branch (for appcast.xml hosting)
- [ ] **Design app icon** — 1024x1024 PNG of the tomato-timer-owl hybrid, saved as `Pomodorni/Assets/AppIcon.png`

## Optional (Recommended Later)

- [ ] **Enroll in Apple Developer Program** ($99/year) — for Developer ID signing + notarization (eliminates Gatekeeper warnings)
- [ ] **Add `DEVELOPER_ID_CERTIFICATE` secret** — base64-encoded .p12 certificate for CI signing
- [ ] **Submit to homebrew-cask** — once the app has enough traction, submit to `homebrew/homebrew-cask` for `brew install --cask pomodorni`
