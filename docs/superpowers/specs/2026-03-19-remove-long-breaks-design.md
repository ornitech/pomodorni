# Remove Long Breaks

## Problem

The automatic long break cycle (every N work sessions) often triggers at the wrong time — after the user has already had a real break (lunch, stepping away) or just started for the day. The rigid counter-based system doesn't match real-world usage patterns.

## Solution

Remove long breaks entirely. Every work session is followed by a break. The break model becomes a simple toggle: work, break, work, break.

## Changes

### Core

- **`SessionType`**: Remove `.longBreak` case. Rename `.shortBreak` to `.break`. `nextSessionType()` becomes a simple toggle — no parameters needed.
- **`TimerEngine`**: Remove `intervalCounter` and all cycle-tracking logic. `completeSession()` increments `completedPomodoros` on work completion only; no cycle reset logic.
- **`Settings`**: Remove `longBreakDuration` and `longBreakInterval` properties and their UserDefaults keys.

### UI

- **Settings view**: Remove long break duration slider and long break interval control.
- **Themes**: Remove `.longBreak` cases from display names, colors, and any theme-specific rendering.
- **Alerts/notifications**: No changes needed — they derive text from `SessionType.displayName`, which will just have `.work` and `.break`.

### Tests

- Remove long break cycle tests.
- Simplify flow tests to work/break alternation.
- Update `SessionType` tests to remove long break cases.

## What stays the same

- Work session duration and behavior.
- Break duration (previously "short break duration") and behavior.
- Auto-start setting.
- Pause, skip, restart, cancel controls.
- Alert panel styles.
- Sound and notification behavior.
- `completedPomodoros` counter.
