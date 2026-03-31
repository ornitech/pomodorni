# Architecture

Pomodorni uses a three-layer design with protocol-based dependency injection for testability.

```
Core (pure Swift)  -->  Themes  -->  Views (SwiftUI)
```

## Core

Pure Swift with no UI dependencies. Contains:

- **TimerEngine** -- state machine managing session lifecycle (idle, running, paused, completed)
- **Settings** -- `@Observable` user preferences persisted to UserDefaults
- **NotificationService** -- system notification dispatch
- **SoundService** -- completion sound playback
- **ActivityMonitor** -- idle detection and nudge logic
- **GlobalShortcutService** -- Carbon Event hotkey registration

## Themes

A `PomodoroTheme` protocol defines the visual contract. Three concrete implementations:

- **MinimalTheme** -- clean, monospaced, indigo accent
- **GlassmorphicTheme** -- glass material with gradient overlays
- **BoldTheme** -- vibrant gradients, large type, thick progress ring

Themes are type-erased via `ThemeContainer` so views don't depend on concrete types.

## Views

SwiftUI views that compose themes and core services:

- **TimerPopoverView** -- main timer UI (progress ring, controls, session info)
- **SettingsView** -- full configuration panel
- **AlertOverlayView** -- session completion alerts (pill, centered, corner)
- **NudgeView** -- activity nudge popup

## Key design decisions

**NSPanel over NSPopover** -- the popover uses NSPanel for precise positioning control, screen edge detection, and non-activating behavior (doesn't steal focus from other apps).

**Protocol-based DI** -- `TimeProvider`, `NotificationProvider`, `SoundProvider`, and `ActivityProvider` are protocols with system implementations. Tests inject mocks.

**Backing field pattern** -- `@Observable` combined with `didSet` and value clamping causes SIGBUS on Int properties. Clamped Int settings use a `_backingField` pattern instead. Simple Bool properties with `didSet` are fine.
