# Activity Nudge Design Spec

Detect when the user appears to be working but hasn't started a pomodoro session, and show a nudge popup offering to start one.

## Problem

Users frequently forget to start pomodoro sessions when they begin working. The app has no way to prompt them, so work goes untracked.

## Solution Overview

A standalone `ActivityMonitor` service that observes keyboard/mouse activity while the timer is idle. After sustained activity exceeding a configurable threshold, a nudge popup appears beneath the menu bar icon with options to start a session, snooze, or silence.

## Architecture

### ActivityProvider Protocol

New protocol in `Core/Protocols/ActivityProvider.swift`:

```swift
protocol ActivityProvider {
    func startMonitoring(onActivity: @escaping () -> Void)
    func stopMonitoring()
}
```

**SystemActivityProvider** — uses `NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .keyDown])`. Each event fires the `onActivity` callback. Intentionally thin — only reports "an input event happened."

**MockActivityProvider** — exposes `simulateActivity()` for deterministic testing.

### ActivityMonitor Service

`@Observable` class. The core orchestrator.

**Init:** `ActivityMonitor(engine:settings:activityProvider:)`

**Behavior:**
- Observes timer engine state — only active when engine is `.idle`
- Tracks last-activity timestamps per rolling sub-window
- Runs a periodic check (~30 seconds) to evaluate sustained activity
- Rolling window: divides the configured delay into 30-second sub-windows. If every sub-window has at least one event, the user is considered actively working. At the 1-minute default, this means 2 consecutive sub-windows with activity triggers the nudge.
- When threshold met → fires `onNudge` callback

**Nudge response states:**
- **Start** — engine starts, monitor stops (engine no longer idle)
- **Remind me in 5 minutes** — pauses monitoring for 5 minutes, then re-evaluates
- **Silence until next session** — stops monitoring entirely. Reactivates when engine transitions through a session and back to `.idle`

**Auto-dismiss on idle:** If the nudge is visible and no input events arrive for 30 seconds, dismiss the nudge and reset the activity tracking cycle.

**Lifecycle:** Observes engine state changes to start/stop monitoring automatically. Stops when engine enters `.running` or `.paused`. Restarts when engine returns to `.idle` (unless silenced).

### NudgePanel

New class in `Core/NudgePanel.swift`. Same NSPanel pattern as `AlertPanel`:

- `.nonactivatingPanel`, floating, transparent background, `.popUpMenu` level
- Pill-style positioning beneath the menu bar icon (same `pillOrigin` logic as `AlertPanel`)
- Methods: `show(statusItemWindow:onStart:onSnooze:onSilence:)`, `dismiss()`, `isVisible`

### NudgeView

SwiftUI view for the popup content:

- Message: "It looks like you're working but haven't started a session. Want to start one now?"
- Three buttons: **Start**, **Remind me in 5 minutes**, **Silence until next session**
- Styled using the app's current `PomodoroTheme`
- Compact pill-style layout, similar visual weight to the completion alert

### Settings Additions

Two new properties in `Settings.swift`:

- `activityNudgeEnabled: Bool` — default `true`. Simple `didSet` pattern.
- `_activityNudgeDelay: Int` — minutes before nudge. Default `1`. Backing field pattern with clamping to `1...30`.

A new section in `SettingsView` — toggle for enable/disable, stepper for delay when enabled.

### AppDelegate Wiring

In `AppDelegate.init()`:

- Create `ActivityMonitor` with `engine`, `settings`, `SystemActivityProvider()`
- Create `NudgePanel` instance
- Wire `activityMonitor.onNudge` to show nudge panel with callbacks:
  - `onStart` → `engine.start()`, dismiss nudge
  - `onSnooze` → `activityMonitor.snooze()`
  - `onSilence` → `activityMonitor.silenceUntilNextSession()`
- Wire idle-dismiss callback to `nudgePanel.dismiss()`
- Dismiss nudge panel when main panel opens (alongside existing `alertPanel.dismiss()`)

## Testing

Unit tests using `MockActivityProvider`:

- Monitoring only starts when engine is idle
- Nudge fires after sustained activity for configured duration
- Snooze delays re-nudge by 5 minutes
- Silence suppresses until next full session cycle (idle → running → idle)
- Auto-dismiss after 30 seconds of no input while nudge is visible
- Monitoring stops when engine starts running
- Respects `activityNudgeEnabled` setting

## Not In Scope

- Accessibility permission prompts (`NSEvent.addGlobalMonitorForEvents` doesn't require them)
- Time-of-day filtering
- Per-app activity detection
- Changes to existing timer logic or session flow
