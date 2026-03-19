# Remove Long Breaks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove long breaks entirely so every work session is followed by a simple break.

**Architecture:** Remove `.longBreak` from `SessionType`, remove `intervalCounter` cycle tracking from `TimerEngine`, remove long break settings. The compiler will catch all switch sites referencing `.longBreak`. Update `displayName` from "Short Break" to "Break".

**Tech Stack:** Swift, SwiftUI, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-19-remove-long-breaks-design.md`

---

### Task 1: Update SessionType

**Files:**
- Modify: `Pomodorni/Core/SessionType.swift`
- Modify: `PomodorniTests/Core/SessionTypeTests.swift`

- [ ] **Step 1: Update tests first — remove long break tests, simplify nextSessionType tests**

Replace the entire test file content with:

```swift
import Testing
@testable import Pomodorni

@Suite("SessionType")
struct SessionTypeTests {
    @Test("has two cases")
    func cases() {
        let allCases: [SessionType] = [.work, .shortBreak]
        #expect(allCases.count == 2)
    }

    @Test("display names are correct")
    func displayNames() {
        #expect(SessionType.work.displayName == "Work")
        #expect(SessionType.shortBreak.displayName == "Break")
    }

    @Test("next session after work is break")
    func nextAfterWork() {
        #expect(SessionType.work.nextSessionType() == .shortBreak)
    }

    @Test("next session after break is work")
    func nextAfterBreak() {
        #expect(SessionType.shortBreak.nextSessionType() == .work)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SessionTypeTests 2>&1 | tail -20`
Expected: compilation errors (`.longBreak` removed from tests but not source yet, and `nextSessionType()` signature mismatch)

- [ ] **Step 3: Update SessionType implementation**

Replace the entire file content of `Pomodorni/Core/SessionType.swift` with:

```swift
import Foundation

enum SessionType: String, Codable, Equatable, Sendable {
    case work
    case shortBreak

    var displayName: String {
        switch self {
        case .work: "Work"
        case .shortBreak: "Break"
        }
    }

    func nextSessionType() -> SessionType {
        switch self {
        case .work: .shortBreak
        case .shortBreak: .work
        }
    }
}
```

- [ ] **Step 4: Run SessionType tests to verify they pass**

Run: `swift test --filter SessionTypeTests 2>&1 | tail -20`
Expected: all 4 tests PASS (but other tests will have compile errors — that's expected, we fix them in subsequent tasks)

- [ ] **Step 5: Commit**

```bash
git add Pomodorni/Core/SessionType.swift PomodorniTests/Core/SessionTypeTests.swift
git commit -m "refactor: remove longBreak from SessionType, simplify to work/break toggle"
```

---

### Task 2: Update Settings

**Files:**
- Modify: `Pomodorni/Core/Settings.swift`
- Modify: `PomodorniTests/Core/SettingsTests.swift`

- [ ] **Step 1: Update tests — remove long break settings tests**

In `PomodorniTests/Core/SettingsTests.swift`:

Remove from the `defaults()` test (lines 13-14):
```swift
        #expect(settings.longBreakDuration == 15)
        #expect(settings.longBreakInterval == 4)
```

Remove the entire `clampLongBreak()` test (lines 57-65):
```swift
    @Test("longBreakDuration clamped to valid range")
    func clampLongBreak() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.longBreakDuration = 0
        #expect(settings.longBreakDuration == 1)
        settings.longBreakDuration = 100
        #expect(settings.longBreakDuration == 60)
    }
```

In the `durationSeconds()` test (line 88), remove:
```swift
        #expect(settings.durationSeconds(for: .longBreak) == 900)
```

- [ ] **Step 2: Update Settings implementation**

In `Pomodorni/Core/Settings.swift`:

Remove the backing fields (lines 17-18):
```swift
    private var _longBreakDuration: Int
    private var _longBreakInterval: Int
```

Remove the `longBreakDuration` property (lines 41-46):
```swift
    var longBreakDuration: Int {
        get { _longBreakDuration }
        set {
            _longBreakDuration = newValue.clamped(to: 1...60)
            defaults.set(_longBreakDuration, forKey: "longBreakDuration")
        }
    }
```

Remove the `longBreakInterval` property (lines 48-53):
```swift
    var longBreakInterval: Int {
        get { _longBreakInterval }
        set {
            _longBreakInterval = newValue.clamped(to: 1...10)
            defaults.set(_longBreakInterval, forKey: "longBreakInterval")
        }
    }
```

In `init`, remove (lines 77-78):
```swift
        self._longBreakDuration = defaults.object(forKey: "longBreakDuration") as? Int ?? 15
        self._longBreakInterval = defaults.object(forKey: "longBreakInterval") as? Int ?? 4
```

In `durationSeconds(for:)`, remove the `.longBreak` case (line 91):
```swift
        case .longBreak: longBreakDuration * 60
```

- [ ] **Step 3: Run Settings tests**

Run: `swift test --filter SettingsTests 2>&1 | tail -20`
Expected: all Settings tests PASS

- [ ] **Step 4: Commit**

```bash
git add Pomodorni/Core/Settings.swift PomodorniTests/Core/SettingsTests.swift
git commit -m "refactor: remove long break duration and interval settings"
```

---

### Task 3: Update TimerEngine

**Files:**
- Modify: `Pomodorni/Core/TimerEngine.swift`
- Modify: `PomodorniTests/Core/TimerEngineTests.swift`

- [ ] **Step 1: Update tests — remove long break tests, simplify makeEngine helper**

In `PomodorniTests/Core/TimerEngineTests.swift`:

Update the `makeEngine` helper (line 9) — remove `longBreakDuration` and `longBreakInterval` parameters:
```swift
    func makeEngine(autoStart: Bool = false, workDuration: Int = 1, shortBreakDuration: Int = 1) -> TimerEngine {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = workDuration
        settings.shortBreakDuration = shortBreakDuration
        settings.autoStartEnabled = autoStart
        return TimerEngine(settings: settings, timeProvider: mockTime)
    }
```

Remove the entire "Long break logic" section (lines 87-109) — both `longBreakAfterInterval()` and `intervalResetsAfterLongBreak()` tests.

- [ ] **Step 2: Update TimerEngine implementation**

In `Pomodorni/Core/TimerEngine.swift`:

Replace the `nextSessionName` computed property (lines 12-15) with:
```swift
    var nextSessionName: String {
        guard let type = state.sessionType else { return "Work" }
        return type.nextSessionType().displayName
    }
```

Remove the `intervalCounter` property (line 17):
```swift
    private var intervalCounter: Int = 0
```

Replace `startNext()` (lines 62-66) with:
```swift
    func startNext() {
        guard case .completed(let type) = state else { return }
        let next = type.nextSessionType()
        beginSession(next)
    }
```

Replace `completeSession()` (lines 94-111) with:
```swift
    private func completeSession(_ type: SessionType) {
        if type == .work {
            completedPomodoros += 1
        }

        onSessionComplete?(type)

        if settings.autoStartEnabled {
            let next = type.nextSessionType()
            beginSession(next)
        } else {
            state = .completed(type)
            remainingSeconds = 0
        }
    }
```

- [ ] **Step 3: Run TimerEngine tests**

Run: `swift test --filter TimerEngineTests 2>&1 | tail -20`
Expected: all TimerEngine tests PASS

- [ ] **Step 4: Commit**

```bash
git add Pomodorni/Core/TimerEngine.swift PomodorniTests/Core/TimerEngineTests.swift
git commit -m "refactor: remove intervalCounter and long break cycle logic from TimerEngine"
```

---

### Task 4: Update services and their tests

**Files:**
- Modify: `Pomodorni/Core/NotificationService.swift:25`
- Modify: `Pomodorni/Core/SoundService.swift:16`
- Modify: `PomodorniTests/Core/NotificationServiceTests.swift`
- No changes needed: `PomodorniTests/Core/SoundServiceTests.swift` (tests only use `.work` and `.shortBreak`)

- [ ] **Step 1: Update NotificationService — remove `.longBreak` from switch**

In `Pomodorni/Core/NotificationService.swift` line 25, change:
```swift
        case .shortBreak, .longBreak:
```
to:
```swift
        case .shortBreak:
```

- [ ] **Step 2: Update SoundService — remove `.longBreak` from switch**

In `Pomodorni/Core/SoundService.swift` line 16, change:
```swift
        case .shortBreak, .longBreak: "Breeze"
```
to:
```swift
        case .shortBreak: "Breeze"
```

- [ ] **Step 3: Update NotificationServiceTests — remove long break test**

In `PomodorniTests/Core/NotificationServiceTests.swift`, remove the entire `longBreakCompleteNotification()` test (lines 27-35):
```swift
    @Test("sends correct notification for long break completion")
    func longBreakCompleteNotification() {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        service.notifySessionComplete(.longBreak)
        #expect(mock.sentNotifications.count == 1)
        #expect(mock.sentNotifications[0].title == "Break's over!")
        #expect(mock.sentNotifications[0].body == "Ready to focus?")
    }
```

- [ ] **Step 4: Run service tests**

Run: `swift test --filter "NotificationServiceTests|SoundServiceTests" 2>&1 | tail -20`
Expected: all service tests PASS

- [ ] **Step 5: Commit**

```bash
git add Pomodorni/Core/NotificationService.swift Pomodorni/Core/SoundService.swift PomodorniTests/Core/NotificationServiceTests.swift
git commit -m "refactor: remove longBreak references from NotificationService and SoundService"
```

---

### Task 5: Update themes

**Files:**
- Modify: `Pomodorni/Themes/GlassmorphicTheme.swift`
- Modify: `Pomodorni/Themes/BoldTheme.swift`

- [ ] **Step 1: Update GlassmorphicTheme — remove `.longBreak` from accentColor**

In `Pomodorni/Themes/GlassmorphicTheme.swift`, replace `accentColor(for:)` (lines 19-25):
```swift
    private func accentColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: .blue
        case .shortBreak: .orange
        }
    }
```

- [ ] **Step 2: Update BoldTheme — remove `.longBreak` from color methods**

In `Pomodorni/Themes/BoldTheme.swift`, replace `gradientColors(for:)` (lines 22-31):
```swift
    private func gradientColors(for sessionType: SessionType?) -> (Color, Color) {
        switch sessionType {
        case .work, .none:
            (Self.owlRed, Self.owlOrange)
        case .shortBreak:
            (Self.owlNavy, Self.owlNavy.opacity(0.85))
        }
    }
```

Replace `primaryColor(for:)` (lines 33-39):
```swift
    private func primaryColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: Self.owlRed
        case .shortBreak: Self.owlNavy
        }
    }
```

- [ ] **Step 3: Verify build compiles**

Run: `swift build 2>&1 | tail -20`
Expected: build succeeds with no errors

- [ ] **Step 4: Commit**

```bash
git add Pomodorni/Themes/GlassmorphicTheme.swift Pomodorni/Themes/BoldTheme.swift
git commit -m "refactor: remove longBreak cases from theme color methods"
```

---

### Task 6: Update TimerState tests and SettingsView

**Files:**
- Modify: `PomodorniTests/Core/TimerStateTests.swift`
- Modify: `Pomodorni/Views/SettingsView.swift`

- [ ] **Step 1: Update TimerStateTests — replace `.longBreak` references**

In `PomodorniTests/Core/TimerStateTests.swift`, change the `completedSession()` test (line 26):
```swift
        let state = TimerState.completed(.longBreak)
```
to:
```swift
        let state = TimerState.completed(.shortBreak)
```

- [ ] **Step 2: Update SettingsView — remove long break controls, rename "Short Break" label**

In `Pomodorni/Views/SettingsView.swift`, replace the `durationSection` (lines 42-58) with:
```swift
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Durations")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            durationRow(label: "Work", value: $settings.workDuration, range: 1...60, unit: "min")
            durationRow(label: "Break", value: $settings.shortBreakDuration, range: 1...30, unit: "min")
        }
    }
```

- [ ] **Step 3: Run all tests**

Run: `swift test 2>&1 | tail -30`
Expected: all tests PASS

- [ ] **Step 4: Commit**

```bash
git add PomodorniTests/Core/TimerStateTests.swift Pomodorni/Views/SettingsView.swift
git commit -m "refactor: update TimerState tests and remove long break settings UI"
```

---

### Task 7: Update integration tests and final verification

**Files:**
- Modify: `PomodorniTests/Integration/PomodoroFlowTests.swift`

- [ ] **Step 1: Update PomodoroFlowTests — remove long break cycle test**

Remove the `longBreakCycle()` test entirely (lines 94-128):
```swift
    @Test("long break cycle: N work sessions trigger long break")
    func longBreakCycle() {
        let mockTime = MockTimeProvider()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = 1
        settings.shortBreakDuration = 1
        settings.longBreakDuration = 1
        settings.longBreakInterval = 2
        settings.autoStartEnabled = true

        let engine = TimerEngine(settings: settings, timeProvider: mockTime)
        engine.start()

        // Work 1 → short break
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.shortBreak))

        // Short break → work 2
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.work))

        // Work 2 → long break (interval = 2)
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.longBreak))
        #expect(engine.completedPomodoros == 2)

        // Long break → work 3
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.work))

        // Work 3 → short break (interval counter reset)
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.shortBreak))
    }
```

- [ ] **Step 2: Run all tests**

Run: `swift test 2>&1 | tail -30`
Expected: ALL tests PASS, zero failures

- [ ] **Step 3: Build the app**

Run: `make build 2>&1 | tail -10`
Expected: release build succeeds

- [ ] **Step 4: Commit**

```bash
git add PomodorniTests/Integration/PomodoroFlowTests.swift
git commit -m "refactor: remove long break cycle integration test"
```
