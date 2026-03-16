# Pomodoro Menu Bar App — Design Spec

## Overview

A native macOS menu bar pomodoro timer built with SwiftUI. Lives in the system status bar with a popover UI. Features configurable timers, three swappable visual themes, global keyboard shortcuts, system sounds, and auto-start chaining.

**Target:** macOS 13+ (Ventura)
**Language:** Swift, SwiftUI
**Architecture:** Three-layer (Core → Theme → UI)

## Requirements

### Core Features
- Configurable work session timer (default 25 min, range 1–60 min)
- Configurable short break timer (default 5 min, range 1–30 min)
- Configurable long break timer (default 15 min, range 1–60 min)
- Long break every N work sessions (default 4, configurable)
- Cancel an ongoing session (returns to idle)
- Restart an ongoing session (resets current timer to full duration)
- Native macOS notifications when work sessions and breaks complete
- Completed pomodoro count display

### Additional Features
- **Global keyboard shortcuts** (configurable, defaults: Ctrl+Option+P start/pause, Ctrl+Option+S skip, Ctrl+Option+R cancel/reset)
- **System sounds** — macOS system sounds on session/break completion, toggleable
- **Auto-start** — Toggleable option to automatically chain work→break→work without manual intervention

### Themes (user-selectable)
- **Minimal** — Clean, monochrome + one accent color, thin circular progress ring
- **Glassmorphic** — Frosted glass materials, subtle gradients shifting by session type
- **Bold** — Saturated distinct colors per mode, thicker animated progress ring

## Architecture

### Layer 1: Core (Pure Swift, no UI imports)

All business logic lives here. Depends only on Foundation and UserNotifications. Fully unit-testable.

#### `SessionType` (enum)
- `.work`
- `.shortBreak`
- `.longBreak`

#### `TimerState` (enum)
- `.idle`
- `.running(SessionType)`
- `.paused(SessionType)`

#### `TimerEngine` (@Observable class)
The central state machine. Owns the countdown timer.

**Properties:**
- `state: TimerState`
- `remainingSeconds: Int`
- `totalSeconds: Int`
- `completedPomodoros: Int`

**Methods:**
- `start()` — Begin a work session from idle
- `pause()` — Pause the current session
- `resume()` — Resume a paused session
- `skip()` — End current session/break early, transition to next
- `cancel()` — Stop and return to idle, reset pomodoro count
- `restart()` — Reset current timer to full duration, stay in same session type

**State transitions:**
```
idle → running(work) → running(shortBreak/longBreak) → running(work) → ...
             ↕                       ↕
         paused(work)         paused(break)
```

Any state can transition to `idle` via `cancel()`.

**Auto-start flow:** When a session completes, if auto-start is enabled, automatically transition to the next session type. If disabled, transition to `idle`.

**Long break logic:** After N completed work sessions, the next break is a long break. Counter resets after a long break.

**Timer implementation:** Uses a `TimeProvider` protocol for the clock source. Production uses `DispatchSourceTimer`; tests inject a controllable mock.

#### `Settings` (@Observable class, backed by UserDefaults/@AppStorage)
- `workDuration: Int` (minutes, 1–60, default 25)
- `shortBreakDuration: Int` (minutes, 1–30, default 5)
- `longBreakDuration: Int` (minutes, 1–60, default 15)
- `longBreakInterval: Int` (sessions, 1–10, default 4)
- `autoStartEnabled: Bool` (default false)
- `soundEnabled: Bool` (default true)
- `selectedTheme: ThemeIdentifier` (default .minimal)
- `showTimeInMenuBar: Bool` (default true)
- Keyboard shortcut bindings for each action

#### `NotificationService`
Wraps `UNUserNotificationCenter`. Depends on a `NotificationProvider` protocol for testability.

- Requests notification permission on first launch
- Sends notification with appropriate title/body per session type:
  - Work complete: "Work session complete — time for a break!"
  - Break complete: "Break's over — ready to focus?"
- Handles permission denied gracefully (no crash, features degrade)

#### `SoundService`
Wraps `NSSound` for playing system sounds. Depends on a `SoundProvider` protocol.

- Different sounds for work-end vs break-end
- Respects `Settings.soundEnabled`
- Fails silently if sound unavailable

### Layer 2: Theme System

#### `PomodoroTheme` protocol
```swift
protocol PomodoroTheme {
    var id: ThemeIdentifier { get }
    var name: String { get }
    var backgroundColor: Color { get }
    var accentColor: Color { get }
    var textColor: Color { get }
    var secondaryTextColor: Color { get }
    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> AnyView
    func controlsView(state: TimerState, onStart: () -> Void, onPause: () -> Void, onResume: () -> Void, onSkip: () -> Void, onCancel: () -> Void, onRestart: () -> Void) -> AnyView
}
```

#### Themes
- **MinimalTheme** — White/dark mode adaptive background, indigo accent, thin `Circle().trim()` progress ring, SF Symbol buttons, SF Mono timer digits
- **GlassmorphicTheme** — `.ultraThinMaterial` background, soft gradient shifts (cool for work, warm for break), rounded frosted panels, subtle shadows
- **BoldTheme** — Deep red (work) / green (short break) / blue (long break), thick animated progress ring, bouncy button transitions

### Layer 3: UI (SwiftUI)

#### App Entry Point
Uses `MenuBarExtra` scene with `.window` style for the popover.

#### Menu Bar Icon
- SF Symbol (`timer`) in status bar
- When running and `showTimeInMenuBar` is on, displays remaining time next to icon (e.g. "18:32")

#### Popover Layout (~300×400pt)
- **Top:** Session type label ("Work" / "Short Break" / "Long Break")
- **Center:** Theme-provided timer display
- **Bottom controls:** Theme-provided control buttons
- **Footer:** Completed pomodoros indicator (e.g. "3/4 until long break"), gear icon for settings

#### Settings Panel
Slides into the popover, replacing the timer view. Contains:
- Duration sliders for work/short break/long break
- Long break interval stepper
- Auto-start toggle
- Theme picker (segmented control)
- Sound toggle
- Keyboard shortcut recorder per action
- Show time in menu bar toggle
- Back button to return to timer

#### Global Keyboard Shortcuts
- Registered via `NSEvent.addGlobalMonitorForEvents` (requires Accessibility permission)
- App prompts for permission on first use with a clear explanation
- Shortcuts configurable via a key recorder in settings
- Defaults: Ctrl+Option+P (start/pause), Ctrl+Option+S (skip), Ctrl+Option+R (cancel/reset)

## Testing Strategy

### Testability Infrastructure
All external dependencies are behind protocols for mockability:
- `TimeProvider` — Controllable clock, no real timers in tests
- `NotificationProvider` — Mock UNUserNotificationCenter
- `SoundProvider` — Mock NSSound

### Unit Tests (Core Layer)
- **TimerEngineTests** — All state transitions, countdown ticks, auto-start behavior, long break interval logic, skip/cancel/restart, edge cases (cancel while paused, restart at 1 second remaining, etc.)
- **SettingsTests** — Default values, persistence round-trip, validation (values clamped to valid ranges)
- **NotificationServiceTests** — Correct content per session type, permission request flow, graceful degradation when denied
- **SoundServiceTests** — Correct sound per event, respects sound-off setting, silent failure

### View/Theme Tests
- Each theme renders correctly for each state combination (idle, running work, running break, paused)
- Theme switching produces expected view hierarchy

### Integration Tests
- Full pomodoro cycle: start → work expires → notification + sound → auto-start break → break expires → notification + sound → idle/auto-start next
- Global shortcut registration and dispatch

## Project Structure

```
Pomodoro/
├── PomodoroApp.swift              # @main, MenuBarExtra scene
├── Core/
│   ├── TimerEngine.swift
│   ├── SessionType.swift
│   ├── TimerState.swift
│   ├── Settings.swift
│   ├── NotificationService.swift
│   ├── SoundService.swift
│   └── Protocols/
│       ├── TimeProvider.swift
│       ├── NotificationProvider.swift
│       └── SoundProvider.swift
├── Themes/
│   ├── PomodoroTheme.swift        # Protocol
│   ├── ThemeIdentifier.swift
│   ├── MinimalTheme/
│   │   └── MinimalTheme.swift
│   ├── GlassmorphicTheme/
│   │   └── GlassmorphicTheme.swift
│   └── BoldTheme/
│       └── BoldTheme.swift
├── Views/
│   ├── TimerPopoverView.swift     # Main popover container
│   ├── SettingsView.swift
│   ├── KeyRecorderView.swift
│   └── MenuBarIconView.swift
└── Tests/
    ├── Core/
    │   ├── TimerEngineTests.swift
    │   ├── SettingsTests.swift
    │   ├── NotificationServiceTests.swift
    │   └── SoundServiceTests.swift
    ├── Themes/
    │   └── ThemeTests.swift
    └── Integration/
        └── PomodoroFlowTests.swift
```

## Non-Goals (explicitly excluded)
- Session history / statistics tracking
- Cloud sync
- iOS/watchOS companion
- Custom sound file loading
- Menubar-only mode (no popover)
