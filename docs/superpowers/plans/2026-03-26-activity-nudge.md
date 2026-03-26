# Activity Nudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect when the user appears to be working without a pomodoro session and show a nudge popup offering to start one.

**Architecture:** A standalone `ActivityMonitor` service with protocol-based DI (`ActivityProvider`) monitors keyboard/mouse events via `NSEvent.addGlobalMonitorForEvents`. A rolling window of 30-second sub-windows determines sustained activity. A new `NudgePanel` + `NudgeView` shows the popup beneath the menu bar icon. The `AppDelegate` orchestrates lifecycle based on engine state transitions detected in its existing 0.5-second display update timer.

**Tech Stack:** Swift, SwiftUI, AppKit (NSPanel, NSEvent), Swift Testing

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `Pomodorni/Core/Protocols/ActivityProvider.swift` | Create | Protocol + SystemActivityProvider |
| `Pomodorni/Core/ActivityMonitor.swift` | Create | Activity tracking, rolling window, nudge orchestration |
| `Pomodorni/Core/NudgePanel.swift` | Create | NSPanel wrapper for nudge popup |
| `Pomodorni/Views/NudgeView.swift` | Create | SwiftUI nudge popup content |
| `Pomodorni/Core/Settings.swift` | Modify | Add `activityNudgeEnabled` and `activityNudgeDelay` |
| `Pomodorni/Views/SettingsView.swift` | Modify | Add nudge settings UI |
| `Pomodorni/PomodorniApp.swift` | Modify | Wire ActivityMonitor + NudgePanel into app lifecycle |
| `PomodorniTests/Mocks/MockActivityProvider.swift` | Create | Mock for testing |
| `PomodorniTests/Core/ActivityMonitorTests.swift` | Create | All ActivityMonitor tests |
| `PomodorniTests/Core/SettingsTests.swift` | Modify | Tests for new settings |

---

### Task 1: ActivityProvider Protocol + MockActivityProvider

**Files:**
- Create: `Pomodorni/Core/Protocols/ActivityProvider.swift`
- Create: `PomodorniTests/Mocks/MockActivityProvider.swift`

- [ ] **Step 1: Create the ActivityProvider protocol**

```swift
// Pomodorni/Core/Protocols/ActivityProvider.swift
import Foundation

protocol ActivityProvider: AnyObject {
    func startMonitoring(onActivity: @escaping () -> Void)
    func stopMonitoring()
}
```

- [ ] **Step 2: Create MockActivityProvider**

```swift
// PomodorniTests/Mocks/MockActivityProvider.swift
import Foundation
@testable import Pomodorni

final class MockActivityProvider: ActivityProvider {
    private var handler: (() -> Void)?
    var isMonitoring = false

    func startMonitoring(onActivity: @escaping () -> Void) {
        handler = onActivity
        isMonitoring = true
    }

    func stopMonitoring() {
        handler = nil
        isMonitoring = false
    }

    /// Simulate a user input event
    func simulateActivity() {
        handler?()
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Pomodorni/Core/Protocols/ActivityProvider.swift PomodorniTests/Mocks/MockActivityProvider.swift
git commit -m "feat: add ActivityProvider protocol and mock"
```

---

### Task 2: ActivityMonitor — Basic Monitoring Lifecycle

**Files:**
- Create: `Pomodorni/Core/ActivityMonitor.swift`
- Create: `PomodorniTests/Core/ActivityMonitorTests.swift`

- [ ] **Step 1: Write failing tests for start/stop monitoring**

```swift
// PomodorniTests/Core/ActivityMonitorTests.swift
import Testing
import Foundation
@testable import Pomodorni

@Suite("ActivityMonitor")
struct ActivityMonitorTests {
    let mockActivity = MockActivityProvider()
    let mockTime = MockTimeProvider()

    func makeMonitor(nudgeDelay: Int = 1, nudgeEnabled: Bool = true) -> ActivityMonitor {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.activityNudgeEnabled = nudgeEnabled
        settings.activityNudgeDelay = nudgeDelay
        return ActivityMonitor(settings: settings, activityProvider: mockActivity, timeProvider: mockTime)
    }

    @Test("startMonitoring activates provider and timer")
    func startActivates() {
        let monitor = makeMonitor()
        monitor.startMonitoring()
        #expect(monitor.isMonitoring)
        #expect(mockActivity.isMonitoring)
        #expect(mockTime.isScheduled)
    }

    @Test("stopMonitoring deactivates provider and timer")
    func stopDeactivates() {
        let monitor = makeMonitor()
        monitor.startMonitoring()
        monitor.stopMonitoring()
        #expect(!monitor.isMonitoring)
        #expect(!mockActivity.isMonitoring)
        #expect(!mockTime.isScheduled)
    }

    @Test("startMonitoring does nothing when nudge disabled")
    func disabledSetting() {
        let monitor = makeMonitor(nudgeEnabled: false)
        monitor.startMonitoring()
        #expect(!monitor.isMonitoring)
        #expect(!mockActivity.isMonitoring)
    }

    @Test("startMonitoring does nothing when silenced")
    func silencedPreventsStart() {
        let monitor = makeMonitor()
        monitor.silenceUntilNextSession()
        monitor.startMonitoring()
        #expect(!monitor.isMonitoring)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ActivityMonitorTests 2>&1 | tail -10`
Expected: FAIL — `ActivityMonitor` not defined

- [ ] **Step 3: Write minimal ActivityMonitor to pass lifecycle tests**

```swift
// Pomodorni/Core/ActivityMonitor.swift
import Foundation

@Observable
final class ActivityMonitor {
    var onNudge: (() -> Void)?
    var onDismissNudge: (() -> Void)?

    private(set) var isMonitoring = false
    private(set) var isNudging = false
    private(set) var isSilenced = false

    private let settings: Settings
    private let activityProvider: ActivityProvider
    private let timeProvider: TimeProvider

    private var hasActivitySinceLastCheck = false
    private var activityWindow: [Bool] = []
    private var idleCheckCount = 0
    private var snoozeChecksRemaining = 0
    private var nudgeOnFirstActivity = false

    static let checkInterval: TimeInterval = 30
    static let idleThresholdChecks = 1
    static let snoozeChecks = 10

    init(settings: Settings, activityProvider: ActivityProvider, timeProvider: TimeProvider = SystemTimeProvider()) {
        self.settings = settings
        self.activityProvider = activityProvider
        self.timeProvider = timeProvider
    }

    func startMonitoring() {
        guard settings.activityNudgeEnabled, !isSilenced else { return }
        stopInternal()
        isMonitoring = true
        hasActivitySinceLastCheck = false
        activityWindow = []
        activityProvider.startMonitoring { [weak self] in
            self?.hasActivitySinceLastCheck = true
        }
        timeProvider.scheduleTick(interval: Self.checkInterval) { [weak self] in
            self?.check()
        }
    }

    func stopMonitoring() {
        stopInternal()
    }

    func snooze() {
        isNudging = false
        isMonitoring = false
        activityProvider.stopMonitoring()
        hasActivitySinceLastCheck = false
        activityWindow = []
        snoozeChecksRemaining = Self.snoozeChecks
        nudgeOnFirstActivity = true
    }

    func silenceUntilNextSession() {
        isSilenced = true
        stopInternal()
    }

    func resetSilence() {
        isSilenced = false
    }

    // MARK: - Private

    private func stopInternal() {
        isMonitoring = false
        isNudging = false
        activityProvider.stopMonitoring()
        timeProvider.invalidate()
        activityWindow = []
        hasActivitySinceLastCheck = false
        idleCheckCount = 0
        snoozeChecksRemaining = 0
        nudgeOnFirstActivity = false
    }

    private func check() {
        if snoozeChecksRemaining > 0 {
            snoozeChecksRemaining -= 1
            if snoozeChecksRemaining == 0 {
                isMonitoring = true
                activityProvider.startMonitoring { [weak self] in
                    self?.hasActivitySinceLastCheck = true
                }
            }
            return
        }

        if isNudging {
            if hasActivitySinceLastCheck {
                idleCheckCount = 0
            } else {
                idleCheckCount += 1
            }
            hasActivitySinceLastCheck = false

            if idleCheckCount >= Self.idleThresholdChecks {
                isNudging = false
                isMonitoring = true
                idleCheckCount = 0
                activityWindow = []
                onDismissNudge?()
            }
            return
        }

        if isMonitoring {
            activityWindow.append(hasActivitySinceLastCheck)
            hasActivitySinceLastCheck = false

            let requiredWindows = max(1, settings.activityNudgeDelay * 2)

            if nudgeOnFirstActivity {
                nudgeOnFirstActivity = false
                if activityWindow.last == true {
                    fireNudge()
                    return
                }
            }

            if activityWindow.count > requiredWindows {
                activityWindow = Array(activityWindow.suffix(requiredWindows))
            }

            if activityWindow.count >= requiredWindows &&
                activityWindow.suffix(requiredWindows).allSatisfy({ $0 }) {
                fireNudge()
            }
        }
    }

    private func fireNudge() {
        isMonitoring = false
        isNudging = true
        idleCheckCount = 0
        activityWindow = []
        onNudge?()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ActivityMonitorTests 2>&1 | tail -10`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add Pomodorni/Core/ActivityMonitor.swift PomodorniTests/Core/ActivityMonitorTests.swift
git commit -m "feat: add ActivityMonitor with basic start/stop lifecycle"
```

---

### Task 3: ActivityMonitor — Sustained Activity Triggers Nudge

**Files:**
- Modify: `PomodorniTests/Core/ActivityMonitorTests.swift`

- [ ] **Step 1: Write failing test for nudge after sustained activity**

Add to `ActivityMonitorTests`:

```swift
@Test("nudge fires after sustained activity for configured delay")
func nudgeAfterSustainedActivity() {
    let monitor = makeMonitor(nudgeDelay: 1) // 1 min = 2 windows of 30s
    var nudgeCount = 0
    monitor.onNudge = { nudgeCount += 1 }

    monitor.startMonitoring()

    // Window 1: activity present
    mockActivity.simulateActivity()
    mockTime.fire()

    // Window 2: activity present
    mockActivity.simulateActivity()
    mockTime.fire()

    #expect(nudgeCount == 1)
    #expect(monitor.isNudging)
    #expect(!monitor.isMonitoring)
}

@Test("nudge does not fire with gap in activity")
func noNudgeWithGap() {
    let monitor = makeMonitor(nudgeDelay: 1)
    var nudgeCount = 0
    monitor.onNudge = { nudgeCount += 1 }

    monitor.startMonitoring()

    // Window 1: activity
    mockActivity.simulateActivity()
    mockTime.fire()

    // Window 2: no activity
    mockTime.fire()

    #expect(nudgeCount == 0)
    #expect(monitor.isMonitoring)
}

@Test("nudge requires correct number of windows for longer delays")
func longerDelay() {
    let monitor = makeMonitor(nudgeDelay: 2) // 2 min = 4 windows
    var nudgeCount = 0
    monitor.onNudge = { nudgeCount += 1 }

    monitor.startMonitoring()

    // 3 windows of activity — not enough
    for _ in 0..<3 {
        mockActivity.simulateActivity()
        mockTime.fire()
    }
    #expect(nudgeCount == 0)

    // 4th window — triggers nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 1)
}

@Test("activity window rolls — old inactive windows are forgotten")
func rollingWindow() {
    let monitor = makeMonitor(nudgeDelay: 1) // 2 windows needed
    var nudgeCount = 0
    monitor.onNudge = { nudgeCount += 1 }

    monitor.startMonitoring()

    // Window 1: no activity
    mockTime.fire()
    // Window 2: activity
    mockActivity.simulateActivity()
    mockTime.fire()
    // Window 3: activity
    mockActivity.simulateActivity()
    mockTime.fire()

    // Windows 2 and 3 both had activity — should nudge
    #expect(nudgeCount == 1)
}
```

- [ ] **Step 2: Run tests to verify they pass**

The implementation from Task 2 already includes the rolling window logic, so these should pass.

Run: `swift test --filter ActivityMonitorTests 2>&1 | tail -15`
Expected: All 8 tests pass

- [ ] **Step 3: Commit**

```bash
git add PomodorniTests/Core/ActivityMonitorTests.swift
git commit -m "test: add sustained activity detection tests for ActivityMonitor"
```

---

### Task 4: ActivityMonitor — Snooze Behavior

**Files:**
- Modify: `PomodorniTests/Core/ActivityMonitorTests.swift`

- [ ] **Step 1: Write failing tests for snooze**

Add to `ActivityMonitorTests`:

```swift
@Test("snooze pauses monitoring for 10 check intervals then re-nudges on activity")
func snoozeAndReNudge() {
    let monitor = makeMonitor(nudgeDelay: 1)
    var nudgeCount = 0
    monitor.onNudge = { nudgeCount += 1 }

    monitor.startMonitoring()

    // Trigger first nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 1)

    // Snooze
    monitor.snooze()
    #expect(!monitor.isNudging)
    #expect(!mockActivity.isMonitoring)

    // 9 checks — still snoozed
    mockTime.fire(times: 9)
    #expect(nudgeCount == 1)

    // 10th check — snooze ends, monitoring restarts
    mockTime.fire()
    #expect(monitor.isMonitoring)
    #expect(mockActivity.isMonitoring)

    // Activity in first window after snooze — immediate re-nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 2)
}

@Test("snooze re-evaluation without activity starts fresh monitoring")
func snoozeNoActivity() {
    let monitor = makeMonitor(nudgeDelay: 1)
    var nudgeCount = 0
    monitor.onNudge = { nudgeCount += 1 }

    monitor.startMonitoring()

    // Trigger nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 1)

    // Snooze
    monitor.snooze()

    // Wait out snooze (10 checks)
    mockTime.fire(times: 10)

    // No activity in first window — no immediate re-nudge
    mockTime.fire()
    #expect(nudgeCount == 1)
    #expect(monitor.isMonitoring)

    // Now sustained activity triggers nudge normally
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 2)
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter ActivityMonitorTests 2>&1 | tail -15`
Expected: All 10 tests pass

- [ ] **Step 3: Commit**

```bash
git add PomodorniTests/Core/ActivityMonitorTests.swift
git commit -m "test: add snooze behavior tests for ActivityMonitor"
```

---

### Task 5: ActivityMonitor — Silence Until Next Session

**Files:**
- Modify: `PomodorniTests/Core/ActivityMonitorTests.swift`

- [ ] **Step 1: Write failing tests for silence**

Add to `ActivityMonitorTests`:

```swift
@Test("silence stops all monitoring")
func silenceStopsEverything() {
    let monitor = makeMonitor()
    monitor.startMonitoring()
    monitor.silenceUntilNextSession()
    #expect(monitor.isSilenced)
    #expect(!monitor.isMonitoring)
    #expect(!mockActivity.isMonitoring)
    #expect(!mockTime.isScheduled)
}

@Test("silence prevents startMonitoring until reset")
func silencePreventsRestart() {
    let monitor = makeMonitor()
    monitor.silenceUntilNextSession()
    monitor.startMonitoring()
    #expect(!monitor.isMonitoring)

    // Reset silence, then start works
    monitor.resetSilence()
    monitor.startMonitoring()
    #expect(monitor.isMonitoring)
}

@Test("resetSilence clears silenced flag")
func resetSilence() {
    let monitor = makeMonitor()
    monitor.silenceUntilNextSession()
    #expect(monitor.isSilenced)
    monitor.resetSilence()
    #expect(!monitor.isSilenced)
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter ActivityMonitorTests 2>&1 | tail -15`
Expected: All 13 tests pass

- [ ] **Step 3: Commit**

```bash
git add PomodorniTests/Core/ActivityMonitorTests.swift
git commit -m "test: add silence behavior tests for ActivityMonitor"
```

---

### Task 6: ActivityMonitor — Auto-Dismiss on Idle

**Files:**
- Modify: `PomodorniTests/Core/ActivityMonitorTests.swift`

- [ ] **Step 1: Write failing tests for idle dismissal**

Add to `ActivityMonitorTests`:

```swift
@Test("nudge auto-dismisses after 1 check with no activity")
func idleDismiss() {
    let monitor = makeMonitor(nudgeDelay: 1)
    var nudgeCount = 0
    var dismissCount = 0
    monitor.onNudge = { nudgeCount += 1 }
    monitor.onDismissNudge = { dismissCount += 1 }

    monitor.startMonitoring()

    // Trigger nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 1)
    #expect(monitor.isNudging)

    // No activity for 1 check → dismiss
    mockTime.fire()
    #expect(dismissCount == 1)
    #expect(!monitor.isNudging)
    #expect(monitor.isMonitoring)
}

@Test("nudge stays visible while user is active")
func nudgeStaysWithActivity() {
    let monitor = makeMonitor(nudgeDelay: 1)
    var dismissCount = 0
    monitor.onNudge = { }
    monitor.onDismissNudge = { dismissCount += 1 }

    monitor.startMonitoring()

    // Trigger nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(monitor.isNudging)

    // Activity during nudge — stays visible
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(dismissCount == 0)
    #expect(monitor.isNudging)

    // Another active check — still visible
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(dismissCount == 0)

    // Now idle — dismiss
    mockTime.fire()
    #expect(dismissCount == 1)
}

@Test("after idle dismiss, sustained activity triggers new nudge")
func reNudgeAfterIdleDismiss() {
    let monitor = makeMonitor(nudgeDelay: 1)
    var nudgeCount = 0
    monitor.onNudge = { nudgeCount += 1 }
    monitor.onDismissNudge = { }

    monitor.startMonitoring()

    // First nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 1)

    // Idle dismiss
    mockTime.fire()

    // New sustained activity → new nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(nudgeCount == 2)
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter ActivityMonitorTests 2>&1 | tail -15`
Expected: All 16 tests pass

- [ ] **Step 3: Commit**

```bash
git add PomodorniTests/Core/ActivityMonitorTests.swift
git commit -m "test: add idle auto-dismiss tests for ActivityMonitor"
```

---

### Task 7: ActivityMonitor — Stop When Engine Starts

**Files:**
- Modify: `PomodorniTests/Core/ActivityMonitorTests.swift`

- [ ] **Step 1: Write test verifying stopMonitoring clears all state**

Add to `ActivityMonitorTests`:

```swift
@Test("stopMonitoring during nudge clears all state")
func stopDuringNudge() {
    let monitor = makeMonitor(nudgeDelay: 1)
    monitor.onNudge = { }
    monitor.startMonitoring()

    // Trigger nudge
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    #expect(monitor.isNudging)

    // Engine starts → stop everything
    monitor.stopMonitoring()
    #expect(!monitor.isNudging)
    #expect(!monitor.isMonitoring)
    #expect(!mockActivity.isMonitoring)
    #expect(!mockTime.isScheduled)
}

@Test("stopMonitoring during snooze clears all state")
func stopDuringSnooze() {
    let monitor = makeMonitor(nudgeDelay: 1)
    monitor.onNudge = { }
    monitor.startMonitoring()

    // Trigger nudge then snooze
    mockActivity.simulateActivity()
    mockTime.fire()
    mockActivity.simulateActivity()
    mockTime.fire()
    monitor.snooze()

    // Engine starts → stop everything
    monitor.stopMonitoring()
    #expect(!monitor.isMonitoring)
    #expect(!mockTime.isScheduled)
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter ActivityMonitorTests 2>&1 | tail -10`
Expected: All 18 tests pass

- [ ] **Step 3: Commit**

```bash
git add PomodorniTests/Core/ActivityMonitorTests.swift
git commit -m "test: add stop-during-nudge and stop-during-snooze tests"
```

---

### Task 8: Settings — Add Nudge Properties

**Files:**
- Modify: `Pomodorni/Core/Settings.swift`
- Modify: `PomodorniTests/Core/SettingsTests.swift`

- [ ] **Step 1: Write failing tests for new settings**

Add to `SettingsTests`:

```swift
@Test("activityNudgeEnabled defaults to true")
func nudgeEnabledDefault() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = Settings(defaults: defaults)
    #expect(settings.activityNudgeEnabled == true)
}

@Test("activityNudgeDelay defaults to 1 and clamps to 1...30")
func nudgeDelayDefault() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = Settings(defaults: defaults)
    #expect(settings.activityNudgeDelay == 1)
    settings.activityNudgeDelay = 0
    #expect(settings.activityNudgeDelay == 1)
    settings.activityNudgeDelay = 50
    #expect(settings.activityNudgeDelay == 30)
}

@Test("nudge settings persist to UserDefaults")
func nudgeSettingsPersist() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = Settings(defaults: defaults)
    settings.activityNudgeEnabled = false
    settings.activityNudgeDelay = 5
    let settings2 = Settings(defaults: defaults)
    #expect(settings2.activityNudgeEnabled == false)
    #expect(settings2.activityNudgeDelay == 5)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SettingsTests 2>&1 | tail -10`
Expected: FAIL — `activityNudgeEnabled` not found

- [ ] **Step 3: Add new properties to Settings**

In `Pomodorni/Core/Settings.swift`, add the backing field alongside the existing ones:

After `private var _shortBreakDuration: Int`, add:

```swift
private var _activityNudgeDelay: Int
```

After the `checkForUpdatesAutomatically` property, add:

```swift
var activityNudgeEnabled: Bool {
    didSet { defaults.set(activityNudgeEnabled, forKey: "activityNudgeEnabled") }
}
var activityNudgeDelay: Int {
    get { _activityNudgeDelay }
    set {
        _activityNudgeDelay = newValue.clamped(to: 1...30)
        defaults.set(_activityNudgeDelay, forKey: "activityNudgeDelay")
    }
}
```

In `init(defaults:)`, after the `checkForUpdatesAutomatically` initialization, add:

```swift
self.activityNudgeEnabled = defaults.object(forKey: "activityNudgeEnabled") as? Bool ?? true
self._activityNudgeDelay = defaults.object(forKey: "activityNudgeDelay") as? Int ?? 1
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SettingsTests 2>&1 | tail -10`
Expected: All tests pass (original + 3 new)

- [ ] **Step 5: Commit**

```bash
git add Pomodorni/Core/Settings.swift PomodorniTests/Core/SettingsTests.swift
git commit -m "feat: add activityNudgeEnabled and activityNudgeDelay settings"
```

---

### Task 9: SystemActivityProvider

**Files:**
- Modify: `Pomodorni/Core/Protocols/ActivityProvider.swift`

- [ ] **Step 1: Add SystemActivityProvider implementation**

Append the `SystemActivityProvider` class to `Pomodorni/Core/Protocols/ActivityProvider.swift` and change the import from `Foundation` to `AppKit` (which re-exports Foundation):

```swift
import AppKit

/// Production activity provider using global NSEvent monitoring.
final class SystemActivityProvider: ActivityProvider {
    private var monitor: Any?

    func startMonitoring(onActivity: @escaping () -> Void) {
        stopMonitoring()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .keyDown]) { _ in
            onActivity()
        }
    }

    func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Pomodorni/Core/Protocols/ActivityProvider.swift
git commit -m "feat: add SystemActivityProvider with NSEvent global monitoring"
```

---

### Task 10: NudgeView

**Files:**
- Create: `Pomodorni/Views/NudgeView.swift`

- [ ] **Step 1: Create NudgeView**

```swift
// Pomodorni/Views/NudgeView.swift
import SwiftUI

struct NudgeView: View {
    let onStart: () -> Void
    let onSnooze: () -> Void
    let onSilence: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "deskclock.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text("It looks like you're working but haven't started a session. Want to start one now?")
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button("Start", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
                Spacer()
                Button("Remind me in 5 minutes", action: onSnooze)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Silence until next session", action: onSilence)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 440)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Pomodorni/Views/NudgeView.swift
git commit -m "feat: add NudgeView for activity nudge popup"
```

---

### Task 11: NudgePanel

**Files:**
- Create: `Pomodorni/Core/NudgePanel.swift`

- [ ] **Step 1: Create NudgePanel**

```swift
// Pomodorni/Core/NudgePanel.swift
import AppKit
import SwiftUI

final class NudgePanel {
    private var panel: NSPanel?

    func show(
        statusItemWindow: NSWindow?,
        onStart: @escaping () -> Void,
        onSnooze: @escaping () -> Void,
        onSilence: @escaping () -> Void
    ) {
        dismiss()

        let view = NudgeView(
            onStart: { [weak self] in
                onStart()
                self?.dismiss()
            },
            onSnooze: { [weak self] in
                onSnooze()
                self?.dismiss()
            },
            onSilence: { [weak self] in
                onSilence()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(hostingView.fittingSize)

        let contentSize = hostingView.fittingSize
        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = false
        newPanel.isReleasedWhenClosed = false
        newPanel.contentView = hostingView

        let origin = pillOrigin(panelSize: contentSize, statusItemWindow: statusItemWindow)
        newPanel.setFrameOrigin(origin)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Positioning

    private func pillOrigin(panelSize: NSSize, statusItemWindow: NSWindow?) -> NSPoint {
        guard let statusFrame = statusItemWindow?.frame,
              let screen = statusItemWindow?.screen ?? NSScreen.main else {
            guard let screen = NSScreen.main else { return .zero }
            let frame = screen.visibleFrame
            return NSPoint(x: frame.midX - panelSize.width / 2, y: frame.midY - panelSize.height / 2)
        }

        let x = statusFrame.midX - panelSize.width / 2
        let y = statusFrame.minY - panelSize.height - 4

        let clampedX = min(max(x, screen.visibleFrame.minX + 4), screen.visibleFrame.maxX - panelSize.width - 4)
        return NSPoint(x: clampedX, y: y)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Pomodorni/Core/NudgePanel.swift
git commit -m "feat: add NudgePanel for positioning nudge popup beneath menu bar"
```

---

### Task 12: AppDelegate Wiring

**Files:**
- Modify: `Pomodorni/PomodorniApp.swift`

- [ ] **Step 1: Add ActivityMonitor and NudgePanel properties**

In `PomodorniApp.swift`, add new properties after `private let alertPanel = AlertPanel()`:

```swift
private let nudgePanel = NudgePanel()
private let activityMonitor: ActivityMonitor
```

Add a state tracking property after `private var keyMonitor: Any?`:

```swift
private var wasIdle = true
```

- [ ] **Step 2: Initialize ActivityMonitor in init()**

In `override init()`, after the `shortcutService` initialization block, add:

```swift
let activityMonitor = ActivityMonitor(
    settings: settings,
    activityProvider: SystemActivityProvider()
)
self.activityMonitor = activityMonitor
```

Then after `super.init()`, after the `shortcutService.register` block, add:

```swift
activityMonitor.onNudge = { [weak self] in
    guard let self else { return }
    self.nudgePanel.show(
        statusItemWindow: self.statusItem?.button?.window,
        onStart: { [weak self] in
            self?.engine.start()
        },
        onSnooze: { [weak self] in
            self?.activityMonitor.snooze()
        },
        onSilence: { [weak self] in
            self?.activityMonitor.silenceUntilNextSession()
        }
    )
}

activityMonitor.onDismissNudge = { [weak self] in
    self?.nudgePanel.dismiss()
}
```

- [ ] **Step 3: Add engine state tracking to the display update timer**

In `applicationDidFinishLaunching`, replace the existing display update timer:

```swift
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    self?.updateTimerDisplay()
}
```

with:

```swift
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    guard let self else { return }
    self.updateTimerDisplay()

    let isIdle = self.engine.state == .idle
    if isIdle != self.wasIdle {
        if isIdle {
            self.activityMonitor.startMonitoring()
        } else {
            self.activityMonitor.stopMonitoring()
            self.activityMonitor.resetSilence()
            self.nudgePanel.dismiss()
        }
        self.wasIdle = isIdle
    }
}
```

- [ ] **Step 4: Start monitoring on app launch**

At the end of `applicationDidFinishLaunching`, add:

```swift
activityMonitor.startMonitoring()
```

- [ ] **Step 5: Dismiss nudge panel when main panel opens**

In the `openPanel()` method, after `alertPanel.dismiss()`, add:

```swift
nudgePanel.dismiss()
```

- [ ] **Step 6: Verify it compiles and all tests pass**

Run: `swift build 2>&1 | tail -5 && swift test 2>&1 | tail -10`
Expected: Build succeeds, all tests pass

- [ ] **Step 7: Commit**

```bash
git add Pomodorni/PomodorniApp.swift
git commit -m "feat: wire ActivityMonitor and NudgePanel into AppDelegate"
```

---

### Task 13: SettingsView — Nudge Settings UI

**Files:**
- Modify: `Pomodorni/Views/SettingsView.swift`

- [ ] **Step 1: Add nudge settings section to SettingsView**

In `SettingsView.swift`, in the `body` VStack, after the `behaviorSection` and its `Divider()`, add a new divider and section:

After:
```swift
behaviorSection
Divider()
```

Add:
```swift
nudgeSection
Divider()
```

Then add the section computed property before `appearanceSection`:

```swift
private var nudgeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Activity Nudge")
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)

        Toggle("Remind me to start a session", isOn: $settings.activityNudgeEnabled)
            .font(.callout)

        if settings.activityNudgeEnabled {
            durationRow(label: "Delay", value: $settings.activityNudgeDelay, range: 1...30, unit: "min")
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Run all tests to confirm nothing broke**

Run: `swift test 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Pomodorni/Views/SettingsView.swift
git commit -m "feat: add activity nudge settings to SettingsView"
```

---

### Task 14: Manual Smoke Test

- [ ] **Step 1: Build and launch the app**

Run: `make run`

- [ ] **Step 2: Verify the nudge appears**

With the app running and no session started:
1. Move the mouse / type on the keyboard for ~60 seconds (default 1-min delay)
2. Verify a nudge popup appears beneath the menu bar icon
3. Verify it shows the correct message and all three buttons

- [ ] **Step 3: Test each button**

1. Click "Remind me in 5 minutes" — nudge dismisses, reappears after ~5 min of continued activity
2. Click "Silence until next session" — nudge dismisses, does not reappear. Start and complete a session, return to idle, verify nudge system reactivates
3. Click "Start" — a work session begins

- [ ] **Step 4: Test idle dismiss**

1. Wait for nudge to appear
2. Stop all mouse/keyboard input for 30+ seconds
3. Verify the nudge auto-dismisses

- [ ] **Step 5: Test settings**

1. Open Settings, find "Activity Nudge" section
2. Toggle off "Remind me to start a session" — verify nudge stops appearing
3. Change delay to 5 minutes — verify nudge takes longer to appear
