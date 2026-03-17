# Pomodorni

macOS menu bar pomodoro timer by Ornitech.

## Conventions

### Commits
Always use conventional commit format:
- `feat:` — new feature
- `fix:` — bug fix
- `refactor:` — code restructuring without behavior change
- `chore:` — build, CI, dependency changes
- `docs:` — documentation only
- `test:` — adding or updating tests

### Pull Requests
- Use descriptive titles
- Add `[minor]` to PR title for feature releases (minor version bump)
- Add `[major]` to PR title for breaking changes (major version bump)
- Default (no tag) = patch version bump

### Build
- `make run` — build debug and launch the app
- `make build` — release build
- `make app` — assemble .app bundle
- `make dmg` — create distributable DMG
- `swift test` — run all tests

### Architecture
- Three-layer: Core (pure Swift) → Themes → Views
- Protocol-based DI for testability (TimeProvider, NotificationProvider, SoundProvider)
- @Observable with private backing fields for Int properties (didSet + @Observable + value clamping causes SIGBUS — use `_backingField` pattern). Simple Bool didSet properties are fine.
- NSPanel for popover (not NSPopover — positioning control)
