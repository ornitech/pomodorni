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

### Versioning
Driven by conventional commit prefixes on the **merge commit** to main:
- `feat!:` (or any `type!:`) — major version bump
- `feat:` — minor version bump
- Everything else (`fix:`, `refactor:`, etc.) — patch version bump

### Pull Requests
- Use descriptive titles in conventional commit format

### Build
- `make run` — build debug and launch the app
- `make build` — release build
- `make app` — assemble .app bundle
- `make dmg` — create distributable DMG
- `swift test` — run all tests
- `make setup` — configure git hooks (run once after cloning)

### Architecture
- Three-layer: Core (pure Swift) → Themes → Views
- Protocol-based DI for testability (TimeProvider, NotificationProvider, SoundProvider)
- @Observable with private backing fields for Int properties (didSet + @Observable + value clamping causes SIGBUS — use `_backingField` pattern). Simple Bool didSet properties are fine.
- NSPanel for popover (not NSPopover — positioning control)
