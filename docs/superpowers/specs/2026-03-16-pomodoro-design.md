# Pomodoro Menu Bar App — Design Spec

## Overview

A native macOS menu bar pomodoro timer built with SwiftUI. Lives in the system status bar with a popover UI. Features configurable timers, three swappable visual themes, global keyboard shortcuts, system sounds, and auto-start chaining.

**Target:** macOS 14+ (Sonoma) — required for `@Observable` macro (Observation framework)
**Language:** Swift 5.9+, SwiftUI
**Architecture:** Three-layer (Core → Theme → UI)

## Requirements

### Core Features
- Configurable work session timer (default 25 min, range 1–60 min)
- Configurable short break timer (default 5 min, range 1–30 min)
- Configurable long break timer (default 15 min, range 1–60 min)
- Long break every N work sessions (default 4, configurable)
- Cancel an ongoing session (returns to idle, preserves completed pomodoro count)
- Restart an ongoing session (resets current timer to full duration)
- Native macOS notifications when work sessions and breaks complete
- Completed pomodoro count display (interval counter resets after long break; total count persists until app quit)

### Additional Features
- **Global keyboard shortcuts** (configurable, defaults: Ctrl+Option+P start/pause, Ctrl+Option+S skip, Ctrl+Option+R reset)
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
- `.completed(SessionType)` — Transient state after a session ends when auto-start is disabled. Shows completion message and a button to start the next session.

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
- `cancel()` — Stop and return to idle. Preserves `completedPomodoros` count (user does not lose progress). Resets the interval counter only if explicitly desired via a separate reset action.
- `restart()` — Reset current timer to full duration, stay in same session type

**State transitions:**
```
idle → running(work) → completed(work) or running(break)
                            ↓
                      running(break) → completed(break) or running(work)

running ↔ paused  (any running state can be paused/resumed)
Any state → idle   (via cancel())
```

When auto-start is enabled, `completed` states are skipped — transitions go directly from one running state to the next. Any state can transition to `idle` via `cancel()`.

**Auto-start flow:** When a session completes, if auto-start is enabled, automatically transition to the next session type. If disabled, transition to `.completed(SessionType)` — a transient state that shows "Session complete!" with a button to manually start the next session. The idle state is only reached via explicit `cancel()`.

**Long break logic:** Two counters:
- `completedPomodoros: Int` — Total completed work sessions this app session. Displayed in the UI. Resets on app quit (not persisted). Not affected by `cancel()`.
- `intervalCounter: Int` — Internal counter tracking work sessions since last long break. After N sessions, the next break is long. Resets to 0 after a long break completes.

**Settings changes mid-session:** Duration changes apply to the *next* session, not the currently running one. This avoids confusion (e.g., timer jumping from 18:00 to 8:00 if work duration is reduced).

**Timer implementation:** Uses a `TimeProvider` protocol for the clock source. Production uses `DispatchSourceTimer`; tests inject a controllable mock. The production timer uses `ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Pomodoro timer active")` to prevent App Nap from suspending the timer while a session is running.

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
- Handles permission denied gracefully: shows a one-time dismissable banner in the popover explaining that notifications are disabled, with a button to open System Settings. No crash, no repeated prompts.

#### `SoundService`
Wraps `NSSound` for playing system sounds. Depends on a `SoundProvider` protocol.

- Different sounds for work-end vs break-end
- Respects `Settings.soundEnabled`
- Fails silently if sound unavailable

### Layer 2: Theme System

#### `PomodoroTheme` protocol

Uses associated types and `@ViewBuilder` to avoid `AnyView` type erasure (which defeats SwiftUI's diffing engine). A `ThemeContainer` view wraps the generic theme in a type-erased container at the point of use.

```swift
protocol PomodoroTheme {
    associatedtype TimerBody: View
    associatedtype ControlsBody: View

    var id: ThemeIdentifier { get }
    var name: String { get }

    @ViewBuilder func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> TimerBody
    @ViewBuilder func controlsView(state: TimerState, onStart: () -> Void, onPause: () -> Void, onResume: () -> Void, onSkip: () -> Void, onCancel: () -> Void, onRestart: () -> Void) -> ControlsBody
}
```

Color properties (background, accent, text) are managed internally by each theme's views rather than exposed on the protocol — this keeps the protocol focused on view composition and lets each theme fully own its visual identity, including dark mode adaptation.

#### Themes
All themes support both light and dark mode (respecting system appearance):
- **MinimalTheme** — Light/dark adaptive background, indigo accent, thin `Circle().trim()` progress ring, SF Symbol buttons, SF Mono timer digits
- **GlassmorphicTheme** — `.ultraThinMaterial` background (adapts automatically to light/dark), soft gradient shifts (cool for work, warm for break), rounded frosted panels, subtle shadows
- **BoldTheme** — Deep red (work) / green (short break) / blue (long break), thick animated progress ring, bouncy button transitions. Colors slightly adjusted for dark mode contrast.

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
- Registered via Carbon's `RegisterEventHotKey` API — the standard macOS approach for global hotkeys. Unlike `NSEvent.addGlobalMonitorForEvents` (which only observes and cannot consume events, and requires Accessibility permission), `RegisterEventHotKey` reliably registers exclusive system-wide hotkeys without Accessibility permission.
- Wrapped in a `GlobalShortcutService` that manages registration/unregistration lifecycle
- Shortcuts configurable via a key recorder in settings
- Defaults: Ctrl+Option+P (start/pause), Ctrl+Option+S (skip), Ctrl+Option+R (reset)
- When shortcuts conflict with another app's registered hotkey, registration fails silently and the user is shown a note in settings

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
- Use `swift-snapshot-testing` (pointfreeco) for visual regression tests of each theme in each state (idle, running work, running break, paused, completed)
- Snapshots captured in both light and dark mode
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
│   ├── GlobalShortcutService.swift
│   └── Protocols/
│       ├── TimeProvider.swift
│       ├── NotificationProvider.swift
│       └── SoundProvider.swift
├── Themes/
│   ├── PomodoroTheme.swift        # Protocol
│   ├── ThemeIdentifier.swift
│   ├── ThemeContainer.swift       # Type-erased wrapper for generic themes
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
    │   └── ThemeSnapshotTests.swift  # swift-snapshot-testing based
    └── Integration/
        └── PomodoroFlowTests.swift
```

## App Lifecycle

- **LSUIElement:** Set `LSUIElement = YES` in Info.plist to hide the Dock icon (menu-bar-only app)
- **State on quit/relaunch:** Timer state is NOT persisted. App always starts in idle. `completedPomodoros` resets on quit.
- **Popover dismissal:** When the popover closes (user clicks away), all state is preserved. Reopening shows the same timer state, settings panel position, etc. The timer continues running in the background.
- **Launch at login:** Not in initial scope (can be added later via `SMAppService`)

## Non-Goals (explicitly excluded)
- Session history / statistics tracking
- Cloud sync
- iOS/watchOS companion
- Custom sound file loading
- Menubar-only mode (no popover)
