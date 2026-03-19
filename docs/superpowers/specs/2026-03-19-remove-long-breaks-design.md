# Remove Long Breaks

## Problem

The automatic long break cycle (every N work sessions) often triggers at the wrong time — after the user has already had a real break (lunch, stepping away) or just started for the day. The rigid counter-based system doesn't match real-world usage patterns.

## Solution

Remove long breaks entirely. Every work session is followed by a break. The break model becomes a simple toggle: work, break, work, break.

## Naming

Keep `.shortBreak` as the internal enum case since `break` is a Swift reserved keyword. Change `displayName` from "Short Break" to "Break". Keep `shortBreakDuration` property name and UserDefaults key unchanged for backward compatibility and minimal churn.

## Changes

### Core

- **`SessionType`**: Remove `.longBreak` case. `nextSessionType()` becomes a simple toggle with no parameters. Update `displayName` to return "Break" instead of "Short Break".
- **`TimerEngine`**: Remove `intervalCounter` and all cycle-tracking logic. `completeSession()` increments `completedPomodoros` on work completion only; no cycle reset. Simplify `nextSessionName` — no more `intervalCounter`/`longBreakInterval` parameters.
- **`Settings`**: Remove `longBreakDuration` and `longBreakInterval` properties and their UserDefaults keys. Orphaned UserDefaults entries are harmless and do not need cleanup.
- **`NotificationService`**: Remove `.longBreak` from switch cases.
- **`SoundService`**: Remove `.longBreak` from switch cases.

### UI

- **Settings view**: Remove long break duration slider and long break interval control. Rename "Short Break" label to "Break".
- **Themes**: Remove `.longBreak` cases from display names, colors, and any theme-specific rendering.

### Tests

- Remove long break cycle tests.
- Simplify flow tests to work/break alternation.
- Update `SessionType` tests to remove long break cases.
- Update `TimerStateTests` — remove `.longBreak` references.
- Update `NotificationServiceTests` — remove long break test.
- Update `SoundServiceTests` — remove `.longBreak` references.
- Update `SettingsTests` — remove long break settings tests.

## Compiler assistance

Removing `.longBreak` from the enum will cause compile errors at every switch site that references it, making it easy to find all locations that need updating. This is the primary safety net.

## What stays the same

- Work session duration and behavior.
- Break duration and behavior (same as previous "short break").
- Auto-start setting.
- Pause, skip, restart, cancel controls.
- Alert panel styles.
- Sound and notification behavior.
- `completedPomodoros` counter.
- Internal property name `shortBreakDuration` and its UserDefaults key.
