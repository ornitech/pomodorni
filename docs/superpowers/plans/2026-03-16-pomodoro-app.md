# Pomodoro Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar pomodoro timer with configurable sessions, three swappable themes, global hotkeys, system sounds, and auto-start chaining.

**Architecture:** Three-layer SwiftUI app (Core → Theme → UI). Core is pure Swift with protocol-based dependency injection for full testability. Themes conform to a `PomodoroTheme` protocol with associated types. UI uses `MenuBarExtra` for the menu bar popover.

**Tech Stack:** Swift 6.0+, SwiftUI, macOS 14+ (Sonoma), Swift Testing, XCTest, swift-snapshot-testing, Carbon (RegisterEventHotKey)

**Note on project format:** We use an Xcode project (not bare SwiftPM) because menu bar apps require a `.app` bundle with `Info.plist` for `LSUIElement` and proper code signing. The Xcode project is generated via `swift package generate-xcodeproj` or created directly in Xcode, with SwiftPM for dependency management.

**Spec:** `docs/superpowers/specs/2026-03-16-pomodoro-design.md`

---

## File Structure

```
Pomodoro/                              # Project root
├── Package.swift                      # SwiftPM manifest (dependency management)
├── Pomodoro/
│   ├── PomodoroApp.swift              # @main, MenuBarExtra scene
│   ├── Info.plist                     # LSUIElement = YES
│   ├── Core/
│   │   ├── SessionType.swift          # SessionType enum
│   │   ├── TimerState.swift           # TimerState enum
│   │   ├── TimerEngine.swift          # @Observable state machine + countdown
│   │   ├── Settings.swift             # @Observable, UserDefaults-backed settings
│   │   ├── NotificationService.swift  # UNUserNotificationCenter wrapper
│   │   ├── SoundService.swift         # NSSound wrapper for system sounds
│   │   ├── GlobalShortcutService.swift # Carbon RegisterEventHotKey wrapper
│   │   └── Protocols/
│   │       ├── TimeProvider.swift     # Protocol for clock source
│   │       ├── NotificationProvider.swift # Protocol for notification center
│   │       └── SoundProvider.swift    # Protocol for sound playback
│   ├── Themes/
│   │   ├── PomodoroTheme.swift        # Theme protocol with associated types
│   │   ├── ThemeIdentifier.swift      # Enum of available themes
│   │   ├── ThemeContainer.swift       # Type-erased wrapper for use in views
│   │   ├── MinimalTheme.swift         # Clean, monochrome + accent color
│   │   ├── GlassmorphicTheme.swift    # Frosted glass, material backgrounds
│   │   └── BoldTheme.swift            # Saturated colors, thick progress ring
│   └── Views/
│       ├── TimerPopoverView.swift     # Main popover container
│       ├── SettingsView.swift         # Settings panel
│       ├── KeyRecorderView.swift      # NSEvent-based shortcut recorder
│       └── Components/
│           └── ProgressRing.swift     # Shared circular progress component
├── PomodoroTests/
│   ├── Core/
│   │   ├── SessionTypeTests.swift
│   │   ├── TimerStateTests.swift
│   │   ├── TimerEngineTests.swift
│   │   ├── SettingsTests.swift
│   │   ├── NotificationServiceTests.swift
│   │   └── SoundServiceTests.swift
│   ├── Mocks/
│   │   ├── MockTimeProvider.swift
│   │   ├── MockNotificationProvider.swift
│   │   └── MockSoundProvider.swift
│   └── Integration/
│       └── PomodoroFlowTests.swift
└── PomodoroSnapshotTests/
    └── ThemeSnapshotTests.swift
```

---

## Chunk 1: Project Setup & Core Types

### Task 1: Create Xcode project and configure build settings

**Files:**
- Create: `Pomodoro.xcodeproj` (via xcodebuild / swift package)
- Create: `Pomodoro/PomodoroApp.swift`
- Create: `Pomodoro/Info.plist`
- Create: `.gitignore`

- [ ] **Step 1: Create the Swift Package-based Xcode project**

We use a Swift Package to manage the project. Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "Pomodoro",
            path: "Pomodoro",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodoroTests",
            dependencies: ["Pomodoro"],
            path: "PomodoroTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodoroSnapshotTests",
            dependencies: [
                "Pomodoro",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "PomodoroSnapshotTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
```

Note: `swift-tools-version: 6.0` provides built-in Swift Testing support (`import Testing`). We use `.swiftLanguageMode(.v5)` to avoid strict concurrency requirements while still getting Swift 6 toolchain features.
```

- [ ] **Step 2: Create the .gitignore**

```
.DS_Store
.build/
*.xcodeproj
xcuserdata/
DerivedData/
.swiftpm/
```

- [ ] **Step 3: Create a minimal app entry point**

Create `Pomodoro/PomodoroApp.swift`:

```swift
import SwiftUI

@main
struct PomodoroApp: App {
    var body: some Scene {
        MenuBarExtra("Pomodoro", systemImage: "timer") {
            Text("Pomodoro Timer")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 4: Create Info.plist**

Create `Pomodoro/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Verify it builds**

Run: `swift build`
Expected: Build succeeds with no errors

- [ ] **Step 6: Commit**

```bash
git add Package.swift .gitignore Pomodoro/ PomodoroTests/ PomodoroSnapshotTests/
git commit -m "feat: scaffold Pomodoro menu bar app with SwiftPM"
```

---

### Task 2: Core enums — SessionType and TimerState

**Files:**
- Create: `Pomodoro/Core/SessionType.swift`
- Create: `Pomodoro/Core/TimerState.swift`
- Test: `PomodoroTests/Core/SessionTypeTests.swift`
- Test: `PomodoroTests/Core/TimerStateTests.swift`

- [ ] **Step 1: Write SessionType tests**

Create `PomodoroTests/Core/SessionTypeTests.swift`:

```swift
import Testing
@testable import Pomodoro

@Suite("SessionType")
struct SessionTypeTests {
    @Test("has three cases")
    func cases() {
        let allCases: [SessionType] = [.work, .shortBreak, .longBreak]
        #expect(allCases.count == 3)
    }

    @Test("display names are correct")
    func displayNames() {
        #expect(SessionType.work.displayName == "Work")
        #expect(SessionType.shortBreak.displayName == "Short Break")
        #expect(SessionType.longBreak.displayName == "Long Break")
    }

    @Test("next session after work is short break by default")
    func nextAfterWork() {
        #expect(SessionType.work.nextSessionType(intervalCounter: 1, longBreakInterval: 4) == .shortBreak)
    }

    @Test("next session after work triggers long break at interval")
    func nextAfterWorkLongBreak() {
        #expect(SessionType.work.nextSessionType(intervalCounter: 4, longBreakInterval: 4) == .longBreak)
    }

    @Test("next session after short break is work")
    func nextAfterShortBreak() {
        #expect(SessionType.shortBreak.nextSessionType(intervalCounter: 1, longBreakInterval: 4) == .work)
    }

    @Test("next session after long break is work")
    func nextAfterLongBreak() {
        #expect(SessionType.longBreak.nextSessionType(intervalCounter: 0, longBreakInterval: 4) == .work)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SessionTypeTests`
Expected: FAIL — `SessionType` not defined

- [ ] **Step 3: Implement SessionType**

Create `Pomodoro/Core/SessionType.swift`:

```swift
import Foundation

enum SessionType: String, Codable, Equatable, Sendable {
    case work
    case shortBreak
    case longBreak

    var displayName: String {
        switch self {
        case .work: "Work"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    func nextSessionType(intervalCounter: Int, longBreakInterval: Int) -> SessionType {
        switch self {
        case .work:
            return intervalCounter >= longBreakInterval ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SessionTypeTests`
Expected: All tests PASS

- [ ] **Step 5: Write TimerState tests**

Create `PomodoroTests/Core/TimerStateTests.swift`:

```swift
import Testing
@testable import Pomodoro

@Suite("TimerState")
struct TimerStateTests {
    @Test("idle has no session type")
    func idleSession() {
        let state = TimerState.idle
        #expect(state.sessionType == nil)
    }

    @Test("running exposes session type")
    func runningSession() {
        let state = TimerState.running(.work)
        #expect(state.sessionType == .work)
    }

    @Test("paused exposes session type")
    func pausedSession() {
        let state = TimerState.paused(.shortBreak)
        #expect(state.sessionType == .shortBreak)
    }

    @Test("completed exposes session type")
    func completedSession() {
        let state = TimerState.completed(.longBreak)
        #expect(state.sessionType == .longBreak)
    }

    @Test("isRunning is true only for running state")
    func isRunning() {
        #expect(TimerState.running(.work).isRunning)
        #expect(!TimerState.idle.isRunning)
        #expect(!TimerState.paused(.work).isRunning)
        #expect(!TimerState.completed(.work).isRunning)
    }

    @Test("isPaused is true only for paused state")
    func isPaused() {
        #expect(TimerState.paused(.work).isPaused)
        #expect(!TimerState.idle.isPaused)
        #expect(!TimerState.running(.work).isPaused)
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `swift test --filter TimerStateTests`
Expected: FAIL — `TimerState` not defined

- [ ] **Step 7: Implement TimerState**

Create `Pomodoro/Core/TimerState.swift`:

```swift
import Foundation

enum TimerState: Equatable, Sendable {
    case idle
    case running(SessionType)
    case paused(SessionType)
    case completed(SessionType)

    var sessionType: SessionType? {
        switch self {
        case .idle: nil
        case .running(let type), .paused(let type), .completed(let type): type
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `swift test --filter TimerStateTests`
Expected: All tests PASS

- [ ] **Step 9: Commit**

```bash
git add Pomodoro/Core/SessionType.swift Pomodoro/Core/TimerState.swift PomodoroTests/Core/
git commit -m "feat: add SessionType and TimerState core enums with tests"
```

---

### Task 3: TimeProvider protocol and MockTimeProvider

**Files:**
- Create: `Pomodoro/Core/Protocols/TimeProvider.swift`
- Create: `PomodoroTests/Mocks/MockTimeProvider.swift`

- [ ] **Step 1: Create TimeProvider protocol**

Create `Pomodoro/Core/Protocols/TimeProvider.swift`:

```swift
import Foundation

protocol TimeProvider: AnyObject {
    /// Schedule a repeating tick. Calls `handler` every `interval` seconds.
    func scheduleTick(interval: TimeInterval, handler: @escaping () -> Void)
    /// Stop all scheduled ticks.
    func invalidate()
}

/// Production timer using DispatchSourceTimer with App Nap prevention.
final class SystemTimeProvider: TimeProvider {
    private var timer: DispatchSourceTimer?
    private var activity: NSObjectProtocol?

    func scheduleTick(interval: TimeInterval, handler: @escaping () -> Void) {
        invalidate()
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Pomodoro timer active"
        )
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler(handler: handler)
        timer.resume()
        self.timer = timer
    }

    func invalidate() {
        timer?.cancel()
        timer = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
```

- [ ] **Step 2: Create MockTimeProvider**

Create `PomodoroTests/Mocks/MockTimeProvider.swift`:

```swift
import Foundation
@testable import Pomodoro

final class MockTimeProvider: TimeProvider {
    private var handler: (() -> Void)?
    var isScheduled = false
    var tickCount = 0

    func scheduleTick(interval: TimeInterval, handler: @escaping () -> Void) {
        self.handler = handler
        isScheduled = true
    }

    func invalidate() {
        handler = nil
        isScheduled = false
    }

    /// Simulate `count` timer ticks
    func fire(times count: Int = 1) {
        for _ in 0..<count {
            tickCount += 1
            handler?()
        }
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Pomodoro/Core/Protocols/TimeProvider.swift PomodoroTests/Mocks/MockTimeProvider.swift
git commit -m "feat: add TimeProvider protocol with system and mock implementations"
```

---

### Task 4: Settings model

**Files:**
- Create: `Pomodoro/Core/Settings.swift`
- Test: `PomodoroTests/Core/SettingsTests.swift`

- [ ] **Step 1: Write Settings tests**

Create `PomodoroTests/Core/SettingsTests.swift`:

```swift
import Testing
import Foundation
@testable import Pomodoro

@Suite("Settings")
struct SettingsTests {
    @Test("default values are correct")
    func defaults() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        #expect(settings.workDuration == 25)
        #expect(settings.shortBreakDuration == 5)
        #expect(settings.longBreakDuration == 15)
        #expect(settings.longBreakInterval == 4)
        #expect(settings.autoStartEnabled == false)
        #expect(settings.soundEnabled == true)
        #expect(settings.showTimeInMenuBar == true)
        #expect(settings.selectedTheme == .minimal)
    }

    @Test("values persist to UserDefaults")
    func persistence() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let settings = Settings(defaults: defaults)
        settings.workDuration = 30
        settings.autoStartEnabled = true
        settings.selectedTheme = .bold

        let settings2 = Settings(defaults: defaults)
        #expect(settings2.workDuration == 30)
        #expect(settings2.autoStartEnabled == true)
        #expect(settings2.selectedTheme == .bold)
    }

    @Test("workDuration clamped to valid range")
    func clampWork() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = 0
        #expect(settings.workDuration == 1)
        settings.workDuration = 100
        #expect(settings.workDuration == 60)
    }

    @Test("shortBreakDuration clamped to valid range")
    func clampShortBreak() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.shortBreakDuration = 0
        #expect(settings.shortBreakDuration == 1)
        settings.shortBreakDuration = 50
        #expect(settings.shortBreakDuration == 30)
    }

    @Test("longBreakDuration clamped to valid range")
    func clampLongBreak() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.longBreakDuration = 0
        #expect(settings.longBreakDuration == 1)
        settings.longBreakDuration = 100
        #expect(settings.longBreakDuration == 60)
    }

    @Test("duration in seconds helper")
    func durationSeconds() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        #expect(settings.durationSeconds(for: .work) == 1500)
        #expect(settings.durationSeconds(for: .shortBreak) == 300)
        #expect(settings.durationSeconds(for: .longBreak) == 900)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsTests`
Expected: FAIL — `Settings` not defined

- [ ] **Step 3: Implement Settings**

Create `Pomodoro/Core/Settings.swift`:

```swift
import Foundation

@Observable
final class Settings {
    private let defaults: UserDefaults

    var workDuration: Int {
        didSet { workDuration = workDuration.clamped(to: 1...60); defaults.set(workDuration, forKey: "workDuration") }
    }
    var shortBreakDuration: Int {
        didSet { shortBreakDuration = shortBreakDuration.clamped(to: 1...30); defaults.set(shortBreakDuration, forKey: "shortBreakDuration") }
    }
    var longBreakDuration: Int {
        didSet { longBreakDuration = longBreakDuration.clamped(to: 1...60); defaults.set(longBreakDuration, forKey: "longBreakDuration") }
    }
    var longBreakInterval: Int {
        didSet { longBreakInterval = longBreakInterval.clamped(to: 1...10); defaults.set(longBreakInterval, forKey: "longBreakInterval") }
    }
    var autoStartEnabled: Bool {
        didSet { defaults.set(autoStartEnabled, forKey: "autoStartEnabled") }
    }
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    var showTimeInMenuBar: Bool {
        didSet { defaults.set(showTimeInMenuBar, forKey: "showTimeInMenuBar") }
    }
    var selectedTheme: ThemeIdentifier {
        didSet { defaults.set(selectedTheme.rawValue, forKey: "selectedTheme") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.workDuration = defaults.object(forKey: "workDuration") as? Int ?? 25
        self.shortBreakDuration = defaults.object(forKey: "shortBreakDuration") as? Int ?? 5
        self.longBreakDuration = defaults.object(forKey: "longBreakDuration") as? Int ?? 15
        self.longBreakInterval = defaults.object(forKey: "longBreakInterval") as? Int ?? 4
        self.autoStartEnabled = defaults.object(forKey: "autoStartEnabled") as? Bool ?? false
        self.soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        self.showTimeInMenuBar = defaults.object(forKey: "showTimeInMenuBar") as? Bool ?? true
        let themeRaw = defaults.string(forKey: "selectedTheme") ?? ThemeIdentifier.minimal.rawValue
        self.selectedTheme = ThemeIdentifier(rawValue: themeRaw) ?? .minimal
    }

    func durationSeconds(for sessionType: SessionType) -> Int {
        switch sessionType {
        case .work: workDuration * 60
        case .shortBreak: shortBreakDuration * 60
        case .longBreak: longBreakDuration * 60
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

Also create the `ThemeIdentifier` enum that `Settings` depends on.

Create `Pomodoro/Themes/ThemeIdentifier.swift`:

```swift
import Foundation

enum ThemeIdentifier: String, CaseIterable, Codable, Sendable {
    case minimal
    case glassmorphic
    case bold
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsTests`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Pomodoro/Core/Settings.swift Pomodoro/Themes/ThemeIdentifier.swift PomodoroTests/Core/SettingsTests.swift
git commit -m "feat: add Settings model with UserDefaults persistence and validation"
```

---

### Task 5: TimerEngine — the core state machine

**Files:**
- Create: `Pomodoro/Core/TimerEngine.swift`
- Test: `PomodoroTests/Core/TimerEngineTests.swift`

- [ ] **Step 1: Write TimerEngine tests — state transitions**

Create `PomodoroTests/Core/TimerEngineTests.swift`:

```swift
import Testing
import Foundation
@testable import Pomodoro

@Suite("TimerEngine")
struct TimerEngineTests {
    let mockTime = MockTimeProvider()

    func makeEngine(autoStart: Bool = false, workDuration: Int = 1, shortBreakDuration: Int = 1, longBreakDuration: Int = 1, longBreakInterval: Int = 4) -> TimerEngine {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = workDuration
        settings.shortBreakDuration = shortBreakDuration
        settings.longBreakDuration = longBreakDuration
        settings.longBreakInterval = longBreakInterval
        settings.autoStartEnabled = autoStart
        return TimerEngine(settings: settings, timeProvider: mockTime)
    }

    // MARK: - Initial state

    @Test("starts in idle state")
    func initialState() {
        let engine = makeEngine()
        #expect(engine.state == .idle)
        #expect(engine.remainingSeconds == 0)
        #expect(engine.completedPomodoros == 0)
    }

    // MARK: - Start

    @Test("start transitions from idle to running work")
    func startFromIdle() {
        let engine = makeEngine()
        engine.start()
        #expect(engine.state == .running(.work))
        #expect(engine.remainingSeconds == 60) // 1 min
        #expect(engine.totalSeconds == 60)
        #expect(mockTime.isScheduled)
    }

    @Test("start does nothing if already running")
    func startWhileRunning() {
        let engine = makeEngine()
        engine.start()
        engine.start() // should be no-op
        #expect(engine.state == .running(.work))
    }

    // MARK: - Countdown

    @Test("tick decrements remaining seconds")
    func tickDecrement() {
        let engine = makeEngine()
        engine.start()
        mockTime.fire(times: 1)
        #expect(engine.remainingSeconds == 59)
    }

    // MARK: - Session completion (auto-start OFF)

    @Test("work session completes to completed state when auto-start disabled")
    func workCompletesNoAutoStart() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .completed(.work))
        #expect(engine.completedPomodoros == 1)
    }

    // MARK: - Session completion (auto-start ON)

    @Test("work session auto-starts short break")
    func workAutoStartsBreak() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.shortBreak))
        #expect(engine.completedPomodoros == 1)
        #expect(engine.remainingSeconds == 60) // 1 min break
    }

    @Test("short break auto-starts next work session")
    func breakAutoStartsWork() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60)  // finish work
        mockTime.fire(times: 60)  // finish break
        #expect(engine.state == .running(.work))
    }

    // MARK: - Long break logic

    @Test("long break triggers after N work sessions")
    func longBreakAfterInterval() {
        let engine = makeEngine(autoStart: true, longBreakInterval: 2)
        engine.start()
        mockTime.fire(times: 60)  // work 1 done → short break
        mockTime.fire(times: 60)  // short break done → work 2
        mockTime.fire(times: 60)  // work 2 done → long break (interval reached)
        #expect(engine.state == .running(.longBreak))
    }

    @Test("interval counter resets after long break")
    func intervalResetsAfterLongBreak() {
        let engine = makeEngine(autoStart: true, longBreakInterval: 2)
        engine.start()
        mockTime.fire(times: 60)  // work 1 → short break
        mockTime.fire(times: 60)  // short break → work 2
        mockTime.fire(times: 60)  // work 2 → long break
        mockTime.fire(times: 60)  // long break → work 3
        #expect(engine.state == .running(.work))
        mockTime.fire(times: 60)  // work 3 → short break (not long, counter reset)
        #expect(engine.state == .running(.shortBreak))
    }

    // MARK: - Pause / Resume

    @Test("pause transitions running to paused")
    func pause() {
        let engine = makeEngine()
        engine.start()
        engine.pause()
        #expect(engine.state == .paused(.work))
        #expect(!mockTime.isScheduled)
    }

    @Test("resume transitions paused to running")
    func resume() {
        let engine = makeEngine()
        engine.start()
        let remaining = engine.remainingSeconds
        engine.pause()
        engine.resume()
        #expect(engine.state == .running(.work))
        #expect(engine.remainingSeconds == remaining)
        #expect(mockTime.isScheduled)
    }

    // MARK: - Cancel

    @Test("cancel returns to idle and preserves pomodoro count")
    func cancel() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60) // complete 1 work → break
        engine.cancel()
        #expect(engine.state == .idle)
        #expect(engine.completedPomodoros == 1) // preserved!
        #expect(!mockTime.isScheduled)
    }

    @Test("cancel from paused state")
    func cancelWhilePaused() {
        let engine = makeEngine()
        engine.start()
        engine.pause()
        engine.cancel()
        #expect(engine.state == .idle)
    }

    // MARK: - Skip

    @Test("skip during work transitions to break")
    func skipWork() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        engine.skip()
        // skip counts as completing the work session
        #expect(engine.state == .completed(.work))
        #expect(engine.completedPomodoros == 1)
    }

    @Test("skip during break transitions to completed break")
    func skipBreak() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60) // work done → break auto-starts
        engine.skip()
        // skip counts as completing the break, next is work
        #expect(engine.state == .running(.work))
    }

    // MARK: - Restart

    @Test("restart resets timer to full duration, same session type")
    func restart() {
        let engine = makeEngine()
        engine.start()
        mockTime.fire(times: 30)
        #expect(engine.remainingSeconds == 30)
        engine.restart()
        #expect(engine.state == .running(.work))
        #expect(engine.remainingSeconds == 60)
    }

    // MARK: - Start next from completed

    @Test("startNext from completed work begins break")
    func startNextFromCompleted() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60) // work done → completed
        #expect(engine.state == .completed(.work))
        engine.startNext()
        #expect(engine.state == .running(.shortBreak))
    }

    @Test("startNext is no-op from non-completed state")
    func startNextFromRunning() {
        let engine = makeEngine()
        engine.start()
        engine.startNext() // should be no-op
        #expect(engine.state == .running(.work))
    }

    // MARK: - Completion callback

    @Test("onSessionComplete callback fires when session ends")
    func completionCallback() {
        let engine = makeEngine(autoStart: false)
        var completedType: SessionType?
        engine.onSessionComplete = { type in completedType = type }
        engine.start()
        mockTime.fire(times: 60)
        #expect(completedType == .work)
    }

    // MARK: - Edge cases

    @Test("skip during break without auto-start goes to completed")
    func skipBreakNoAutoStart() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60) // work done → completed
        engine.startNext() // start break
        engine.skip()
        #expect(engine.state == .completed(.shortBreak))
    }

    @Test("skip while paused works")
    func skipWhilePaused() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        engine.pause()
        engine.skip()
        #expect(engine.state == .completed(.work))
        #expect(engine.completedPomodoros == 1)
    }

    @Test("restart at 1 second remaining resets to full duration")
    func restartAtOneSecond() {
        let engine = makeEngine()
        engine.start()
        mockTime.fire(times: 59)
        #expect(engine.remainingSeconds == 1)
        engine.restart()
        #expect(engine.remainingSeconds == 60)
        #expect(engine.state == .running(.work))
    }

    @Test("double pause is no-op")
    func doublePause() {
        let engine = makeEngine()
        engine.start()
        engine.pause()
        engine.pause() // should be no-op
        #expect(engine.state == .paused(.work))
    }

    @Test("double resume is no-op")
    func doubleResume() {
        let engine = makeEngine()
        engine.start()
        engine.resume() // not paused, should be no-op
        #expect(engine.state == .running(.work))
    }

    @Test("start from completed state is no-op")
    func startFromCompleted() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .completed(.work))
        engine.start() // should be no-op, use startNext instead
        #expect(engine.state == .completed(.work))
    }

    @Test("settings changes mid-session do not affect running timer")
    func settingsMidSession() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = 1 // 60 seconds
        settings.autoStartEnabled = false
        let engine = TimerEngine(settings: settings, timeProvider: mockTime)

        engine.start()
        #expect(engine.totalSeconds == 60)
        mockTime.fire(times: 10)

        // Change duration mid-session
        settings.workDuration = 2 // 120 seconds
        #expect(engine.remainingSeconds == 50) // unaffected
        #expect(engine.totalSeconds == 60) // unaffected
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TimerEngineTests`
Expected: FAIL — `TimerEngine` not defined

- [ ] **Step 3: Implement TimerEngine**

Create `Pomodoro/Core/TimerEngine.swift`:

```swift
import Foundation

@Observable
final class TimerEngine {
    private(set) var state: TimerState = .idle
    private(set) var remainingSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var completedPomodoros: Int = 0

    var onSessionComplete: ((SessionType) -> Void)?

    private var intervalCounter: Int = 0
    private let settings: Settings
    private let timeProvider: TimeProvider

    init(settings: Settings, timeProvider: TimeProvider = SystemTimeProvider()) {
        self.settings = settings
        self.timeProvider = timeProvider
    }

    func start() {
        guard state == .idle else { return }
        beginSession(.work)
    }

    func pause() {
        guard case .running(let type) = state else { return }
        timeProvider.invalidate()
        state = .paused(type)
    }

    func resume() {
        guard case .paused(let type) = state else { return }
        state = .running(type)
        startTicking()
    }

    func skip() {
        guard let type = state.sessionType, state.isRunning || state.isPaused else { return }
        timeProvider.invalidate()
        completeSession(type)
    }

    func cancel() {
        timeProvider.invalidate()
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
    }

    func restart() {
        guard let type = state.sessionType, (state.isRunning || state.isPaused) else { return }
        timeProvider.invalidate()
        beginSession(type)
    }

    func startNext() {
        guard case .completed(let type) = state else { return }
        let next = type.nextSessionType(intervalCounter: intervalCounter, longBreakInterval: settings.longBreakInterval)
        beginSession(next)
    }

    // MARK: - Private

    private func beginSession(_ type: SessionType) {
        let duration = settings.durationSeconds(for: type)
        totalSeconds = duration
        remainingSeconds = duration
        state = .running(type)
        startTicking()
    }

    private func startTicking() {
        timeProvider.scheduleTick(interval: 1.0) { [weak self] in
            self?.tick()
        }
    }

    private func tick() {
        guard state.isRunning else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            guard case .running(let type) = state else { return }
            timeProvider.invalidate()
            completeSession(type)
        }
    }

    private func completeSession(_ type: SessionType) {
        if type == .work {
            completedPomodoros += 1
            intervalCounter += 1
        } else if type == .longBreak {
            intervalCounter = 0
        }

        onSessionComplete?(type)

        if settings.autoStartEnabled {
            let next = type.nextSessionType(intervalCounter: intervalCounter, longBreakInterval: settings.longBreakInterval)
            beginSession(next)
        } else {
            state = .completed(type)
            remainingSeconds = 0
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TimerEngineTests`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Pomodoro/Core/TimerEngine.swift PomodoroTests/Core/TimerEngineTests.swift
git commit -m "feat: add TimerEngine state machine with full test coverage"
```

---

## Chunk 2: Services (Notifications, Sound) & Theme System

### Task 6: NotificationProvider protocol and NotificationService

**Files:**
- Create: `Pomodoro/Core/Protocols/NotificationProvider.swift`
- Create: `Pomodoro/Core/NotificationService.swift`
- Create: `PomodoroTests/Mocks/MockNotificationProvider.swift`
- Test: `PomodoroTests/Core/NotificationServiceTests.swift`

- [ ] **Step 1: Write NotificationService tests**

Create `PomodoroTests/Mocks/MockNotificationProvider.swift`:

```swift
import Foundation
@testable import Pomodoro

final class MockNotificationProvider: NotificationProvider {
    var authorizationGranted = true
    var requestedAuthorization = false
    var sentNotifications: [(title: String, body: String)] = []

    func requestAuthorization() async -> Bool {
        requestedAuthorization = true
        return authorizationGranted
    }

    func send(title: String, body: String) {
        sentNotifications.append((title: title, body: body))
    }

    func checkAuthorizationStatus() async -> Bool {
        return authorizationGranted
    }
}
```

Create `PomodoroTests/Core/NotificationServiceTests.swift`:

```swift
import Testing
import Foundation
@testable import Pomodoro

@Suite("NotificationService")
struct NotificationServiceTests {
    @Test("sends correct notification for work completion")
    func workCompleteNotification() {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        service.notifySessionComplete(.work)
        #expect(mock.sentNotifications.count == 1)
        #expect(mock.sentNotifications[0].title == "Work session complete!")
        #expect(mock.sentNotifications[0].body == "Time for a break.")
    }

    @Test("sends correct notification for short break completion")
    func shortBreakCompleteNotification() {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        service.notifySessionComplete(.shortBreak)
        #expect(mock.sentNotifications.count == 1)
        #expect(mock.sentNotifications[0].title == "Break's over!")
        #expect(mock.sentNotifications[0].body == "Ready to focus?")
    }

    @Test("sends correct notification for long break completion")
    func longBreakCompleteNotification() {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        service.notifySessionComplete(.longBreak)
        #expect(mock.sentNotifications.count == 1)
        #expect(mock.sentNotifications[0].title == "Break's over!")
        #expect(mock.sentNotifications[0].body == "Ready to focus?")
    }

    @Test("requests authorization")
    async func requestAuth() async {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        let granted = await service.requestPermission()
        #expect(mock.requestedAuthorization)
        #expect(granted)
    }

    @Test("handles denied authorization")
    async func deniedAuth() async {
        let mock = MockNotificationProvider()
        mock.authorizationGranted = false
        let service = NotificationService(provider: mock)
        let granted = await service.requestPermission()
        #expect(!granted)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter NotificationServiceTests`
Expected: FAIL — types not defined

- [ ] **Step 3: Implement NotificationProvider and NotificationService**

Create `Pomodoro/Core/Protocols/NotificationProvider.swift`:

```swift
import Foundation

protocol NotificationProvider: AnyObject {
    func requestAuthorization() async -> Bool
    func send(title: String, body: String)
    func checkAuthorizationStatus() async -> Bool
}
```

Create `Pomodoro/Core/NotificationService.swift`:

```swift
import Foundation
import UserNotifications

final class NotificationService {
    private let provider: NotificationProvider
    private(set) var isAuthorized = false

    init(provider: NotificationProvider = SystemNotificationProvider()) {
        self.provider = provider
    }

    func requestPermission() async -> Bool {
        isAuthorized = await provider.requestAuthorization()
        return isAuthorized
    }

    func checkPermission() async {
        isAuthorized = await provider.checkAuthorizationStatus()
    }

    func notifySessionComplete(_ sessionType: SessionType) {
        let (title, body): (String, String) = switch sessionType {
        case .work:
            ("Work session complete!", "Time for a break.")
        case .shortBreak, .longBreak:
            ("Break's over!", "Ready to focus?")
        }
        provider.send(title: title, body: body)
    }
}

/// Production implementation wrapping UNUserNotificationCenter
final class SystemNotificationProvider: NotificationProvider {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func checkAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NotificationServiceTests`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Pomodoro/Core/Protocols/NotificationProvider.swift Pomodoro/Core/NotificationService.swift PomodoroTests/Mocks/MockNotificationProvider.swift PomodoroTests/Core/NotificationServiceTests.swift
git commit -m "feat: add NotificationService with provider protocol and tests"
```

---

### Task 7: SoundProvider protocol and SoundService

**Files:**
- Create: `Pomodoro/Core/Protocols/SoundProvider.swift`
- Create: `Pomodoro/Core/SoundService.swift`
- Create: `PomodoroTests/Mocks/MockSoundProvider.swift`
- Test: `PomodoroTests/Core/SoundServiceTests.swift`

- [ ] **Step 1: Write SoundService tests**

Create `PomodoroTests/Mocks/MockSoundProvider.swift`:

```swift
@testable import Pomodoro

final class MockSoundProvider: SoundProvider {
    var playedSounds: [String] = []

    func play(systemSound name: String) {
        playedSounds.append(name)
    }
}
```

Create `PomodoroTests/Core/SoundServiceTests.swift`:

```swift
import Testing
import Foundation
@testable import Pomodoro

@Suite("SoundService")
struct SoundServiceTests {
    @Test("plays sound for work completion when enabled")
    func workCompleteSound() {
        let mock = MockSoundProvider()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.soundEnabled = true
        let service = SoundService(provider: mock, settings: settings)
        service.playSessionComplete(.work)
        #expect(mock.playedSounds.count == 1)
        #expect(mock.playedSounds[0] == "Glass")
    }

    @Test("plays different sound for break completion")
    func breakCompleteSound() {
        let mock = MockSoundProvider()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.soundEnabled = true
        let service = SoundService(provider: mock, settings: settings)
        service.playSessionComplete(.shortBreak)
        #expect(mock.playedSounds.count == 1)
        #expect(mock.playedSounds[0] == "Breeze")
    }

    @Test("does not play sound when disabled")
    func soundDisabled() {
        let mock = MockSoundProvider()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.soundEnabled = false
        let service = SoundService(provider: mock, settings: settings)
        service.playSessionComplete(.work)
        #expect(mock.playedSounds.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SoundServiceTests`
Expected: FAIL — types not defined

- [ ] **Step 3: Implement SoundProvider and SoundService**

Create `Pomodoro/Core/Protocols/SoundProvider.swift`:

```swift
import Foundation

protocol SoundProvider: AnyObject {
    func play(systemSound name: String)
}
```

Create `Pomodoro/Core/SoundService.swift`:

```swift
import AppKit

final class SoundService {
    private let provider: SoundProvider
    private let settings: Settings

    init(provider: SoundProvider = SystemSoundProvider(), settings: Settings) {
        self.provider = provider
        self.settings = settings
    }

    func playSessionComplete(_ sessionType: SessionType) {
        guard settings.soundEnabled else { return }
        let soundName = switch sessionType {
        case .work: "Glass"
        case .shortBreak, .longBreak: "Breeze"
        }
        provider.play(systemSound: soundName)
    }
}

final class SystemSoundProvider: SoundProvider {
    func play(systemSound name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SoundServiceTests`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Pomodoro/Core/Protocols/SoundProvider.swift Pomodoro/Core/SoundService.swift PomodoroTests/Mocks/MockSoundProvider.swift PomodoroTests/Core/SoundServiceTests.swift
git commit -m "feat: add SoundService with provider protocol and tests"
```

---

### Task 8: Theme protocol and ThemeContainer

**Files:**
- Create: `Pomodoro/Themes/PomodoroTheme.swift`
- Create: `Pomodoro/Themes/ThemeContainer.swift`

- [ ] **Step 1: Create PomodoroTheme protocol**

Create `Pomodoro/Themes/PomodoroTheme.swift`:

```swift
import SwiftUI

protocol PomodoroTheme {
    associatedtype TimerBody: View
    associatedtype ControlsBody: View
    associatedtype CompletedBody: View

    var id: ThemeIdentifier { get }
    var name: String { get }

    @ViewBuilder func timerView(
        remainingSeconds: Int,
        totalSeconds: Int,
        sessionType: SessionType,
        state: TimerState
    ) -> TimerBody

    @ViewBuilder func controlsView(
        state: TimerState,
        onStart: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRestart: @escaping () -> Void
    ) -> ControlsBody

    @ViewBuilder func completedView(
        sessionType: SessionType,
        onStartNext: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> CompletedBody
}
```

- [ ] **Step 2: Create ThemeContainer**

Create `Pomodoro/Themes/ThemeContainer.swift`:

```swift
import SwiftUI

/// Type-erased wrapper so the popover can hold any theme.
/// AnyView is used here at the composition boundary — individual themes
/// return concrete types via @ViewBuilder.
struct ThemeContainer {
    private let _timerView: (Int, Int, SessionType, TimerState) -> AnyView
    private let _controlsView: (TimerState, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void) -> AnyView
    private let _completedView: (SessionType, @escaping () -> Void, @escaping () -> Void) -> AnyView

    let id: ThemeIdentifier
    let name: String

    init<T: PomodoroTheme>(_ theme: T) {
        self.id = theme.id
        self.name = theme.name
        self._timerView = { AnyView(theme.timerView(remainingSeconds: $0, totalSeconds: $1, sessionType: $2, state: $3)) }
        self._controlsView = { AnyView(theme.controlsView(state: $0, onStart: $1, onPause: $2, onResume: $3, onSkip: $4, onCancel: $5, onRestart: $6)) }
        self._completedView = { AnyView(theme.completedView(sessionType: $0, onStartNext: $1, onCancel: $2)) }
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        _timerView(remainingSeconds, totalSeconds, sessionType, state)
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        _controlsView(state, onStart, onPause, onResume, onSkip, onCancel, onRestart)
    }

    func completedView(sessionType: SessionType, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        _completedView(sessionType, onStartNext, onCancel)
    }

    static let allThemes: [ThemeContainer] = [
        ThemeContainer(MinimalTheme()),
        ThemeContainer(GlassmorphicTheme()),
        ThemeContainer(BoldTheme())
    ]

    static func theme(for id: ThemeIdentifier) -> ThemeContainer {
        allThemes.first { $0.id == id } ?? ThemeContainer(MinimalTheme())
    }
}
```

Note: `allThemes` will cause a build error until the three themes are implemented in Task 10. For now, comment those out or add placeholder themes. We'll wire them up in Task 10.

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: Build succeeds (may need temporary stubs)

- [ ] **Step 4: Commit**

```bash
git add Pomodoro/Themes/PomodoroTheme.swift Pomodoro/Themes/ThemeContainer.swift
git commit -m "feat: add PomodoroTheme protocol and ThemeContainer type-erased wrapper"
```

---

### Task 9: Shared ProgressRing component

**Files:**
- Create: `Pomodoro/Views/Components/ProgressRing.swift`

- [ ] **Step 1: Create ProgressRing view**

Create `Pomodoro/Views/Components/ProgressRing.swift`:

```swift
import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let trackColor: Color
    let progressColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Pomodoro/Views/Components/ProgressRing.swift
git commit -m "feat: add shared ProgressRing SwiftUI component"
```

---

### Task 10: Three themes — Minimal, Glassmorphic, Bold

**Files:**
- Create: `Pomodoro/Themes/MinimalTheme.swift`
- Create: `Pomodoro/Themes/GlassmorphicTheme.swift`
- Create: `Pomodoro/Themes/BoldTheme.swift`

- [ ] **Step 1: Implement MinimalTheme**

Create `Pomodoro/Themes/MinimalTheme.swift`:

```swift
import SwiftUI

struct MinimalTheme: PomodoroTheme {
    let id = ThemeIdentifier.minimal
    let name = "Minimal"

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
        VStack(spacing: 16) {
            Text(sessionType.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 6,
                    trackColor: Color(.separatorColor),
                    progressColor: .indigo
                )
                .frame(width: 160, height: 160)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 42, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 20) {
            switch state {
            case .idle:
                iconButton("play.fill", action: onStart)
            case .running:
                iconButton("pause.fill", action: onPause)
                iconButton("forward.fill", action: onSkip)
                iconButton("arrow.counterclockwise", action: onRestart)
                iconButton("xmark", action: onCancel)
            case .paused:
                iconButton("play.fill", action: onResume)
                iconButton("forward.fill", action: onSkip)
                iconButton("arrow.counterclockwise", action: onRestart)
                iconButton("xmark", action: onCancel)
            case .completed:
                EmptyView() // handled by completedView
            }
        }
        .font(.title2)
    }

    func completedView(sessionType: SessionType, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("\(sessionType.displayName) complete!")
                .font(.headline)
            HStack(spacing: 16) {
                Button("Start Next", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                Button("Done", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.indigo)
        }
        .buttonStyle(.plain)
    }
}

```

Also create `Pomodoro/Core/FormatTime.swift`:

```swift
import Foundation

func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
```

This is used by all themes and the menu bar label.

- [ ] **Step 2: Implement GlassmorphicTheme**

Create `Pomodoro/Themes/GlassmorphicTheme.swift`:

```swift
import SwiftUI

struct GlassmorphicTheme: PomodoroTheme {
    let id = ThemeIdentifier.glassmorphic
    let name = "Glassmorphic"

    private func accentColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: .blue
        case .shortBreak: .orange
        case .longBreak: .purple
        }
    }

    private func gradient(for sessionType: SessionType) -> LinearGradient {
        let color = accentColor(for: sessionType)
        return LinearGradient(
            colors: [color.opacity(0.3), color.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
        VStack(spacing: 16) {
            Text(sessionType.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 8,
                    trackColor: .white.opacity(0.15),
                    progressColor: accentColor(for: sessionType)
                )
                .frame(width: 160, height: 160)
                .shadow(color: accentColor(for: sessionType).opacity(0.3), radius: 10)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 42, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(gradient(for: sessionType))
                )
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            switch state {
            case .idle:
                glassButton("play.fill", action: onStart)
            case .running:
                glassButton("pause.fill", action: onPause)
                glassButton("forward.fill", action: onSkip)
                glassButton("arrow.counterclockwise", action: onRestart)
                glassButton("xmark", action: onCancel)
            case .paused:
                glassButton("play.fill", action: onResume)
                glassButton("forward.fill", action: onSkip)
                glassButton("arrow.counterclockwise", action: onRestart)
                glassButton("xmark", action: onCancel)
            case .completed:
                EmptyView()
            }
        }
    }

    func completedView(sessionType: SessionType, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(accentColor(for: sessionType))
            Text("\(sessionType.displayName) complete!")
                .font(.headline)
            HStack(spacing: 16) {
                Button("Start Next", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor(for: sessionType))
                Button("Done", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private func glassButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Implement BoldTheme**

Create `Pomodoro/Themes/BoldTheme.swift`:

```swift
import SwiftUI

struct BoldTheme: PomodoroTheme {
    let id = ThemeIdentifier.bold
    let name = "Bold"

    private func primaryColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: .red
        case .shortBreak: .green
        case .longBreak: .blue
        }
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
        let color = primaryColor(for: sessionType)
        VStack(spacing: 16) {
            Text(sessionType.displayName)
                .font(.headline.bold())
                .foregroundStyle(color)

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 12,
                    trackColor: color.opacity(0.2),
                    progressColor: color
                )
                .frame(width: 160, height: 160)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            switch state {
            case .idle:
                boldButton("play.fill", color: .red, action: onStart)
            case .running(let type):
                boldButton("pause.fill", color: primaryColor(for: type), action: onPause)
                boldButton("forward.fill", color: primaryColor(for: type), action: onSkip)
                boldButton("arrow.counterclockwise", color: primaryColor(for: type), action: onRestart)
                boldButton("xmark", color: .gray, action: onCancel)
            case .paused(let type):
                boldButton("play.fill", color: primaryColor(for: type), action: onResume)
                boldButton("forward.fill", color: primaryColor(for: type), action: onSkip)
                boldButton("arrow.counterclockwise", color: primaryColor(for: type), action: onRestart)
                boldButton("xmark", color: .gray, action: onCancel)
            case .completed:
                EmptyView()
            }
        }
    }

    func completedView(sessionType: SessionType, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        let color = primaryColor(for: sessionType)
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(color)
                .scaleEffect(1.1)
            Text("\(sessionType.displayName) complete!")
                .font(.headline.bold())
                .foregroundStyle(color)
            HStack(spacing: 16) {
                Button("Start Next", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                Button("Done", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func boldButton(_ systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
```

- [ ] **Step 4: Uncomment ThemeContainer.allThemes and verify build**

Ensure `ThemeContainer.allThemes` references all three themes. Run:

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add Pomodoro/Themes/
git commit -m "feat: add Minimal, Glassmorphic, and Bold themes"
```

---

## Chunk 3: UI Layer — Popover, Settings, Menu Bar

### Task 11: TimerPopoverView — main popover container

**Files:**
- Create: `Pomodoro/Views/TimerPopoverView.swift`

- [ ] **Step 1: Implement TimerPopoverView**

Create `Pomodoro/Views/TimerPopoverView.swift`:

```swift
import SwiftUI

struct TimerPopoverView: View {
    @Bindable var engine: TimerEngine
    @Bindable var settings: Settings
    @State private var showSettings = false

    private var theme: ThemeContainer {
        ThemeContainer.theme(for: settings.selectedTheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(settings: settings, onDismiss: { showSettings = false })
            } else {
                timerContent
            }
        }
        .frame(width: 300, height: 400)
    }

    @ViewBuilder
    private var timerContent: some View {
        VStack(spacing: 20) {
            Spacer()

            switch engine.state {
            case .idle:
                idleView
            case .running(let type), .paused(let type):
                theme.timerView(
                    remainingSeconds: engine.remainingSeconds,
                    totalSeconds: engine.totalSeconds,
                    sessionType: type,
                    state: engine.state
                )
                theme.controlsView(
                    state: engine.state,
                    onStart: engine.start,
                    onPause: engine.pause,
                    onResume: engine.resume,
                    onSkip: engine.skip,
                    onCancel: engine.cancel,
                    onRestart: engine.restart
                )
            case .completed(let type):
                theme.completedView(
                    sessionType: type,
                    onStartNext: engine.startNext,
                    onCancel: engine.cancel
                )
            }

            Spacer()

            footer
        }
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ready to focus?")
                .font(.title3)
            Button("Start", action: engine.start)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var footer: some View {
        HStack {
            if engine.completedPomodoros > 0 {
                Text("\(engine.completedPomodoros) pomodoro\(engine.completedPomodoros == 1 ? "" : "s") completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Pomodoro/Views/TimerPopoverView.swift
git commit -m "feat: add TimerPopoverView main popover container"
```

---

### Task 12: SettingsView

**Files:**
- Create: `Pomodoro/Views/SettingsView.swift`

- [ ] **Step 1: Implement SettingsView**

Create `Pomodoro/Views/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                durationSection
                Divider()
                behaviorSection
                Divider()
                appearanceSection
            }
            .padding()
        }
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Settings")
                .font(.headline)
            Spacer()
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Durations")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            durationRow(label: "Work", value: $settings.workDuration, range: 1...60, unit: "min")
            durationRow(label: "Short Break", value: $settings.shortBreakDuration, range: 1...30, unit: "min")
            durationRow(label: "Long Break", value: $settings.longBreakDuration, range: 1...60, unit: "min")

            HStack {
                Text("Long break every")
                Stepper("\(settings.longBreakInterval) sessions", value: $settings.longBreakInterval, in: 1...10)
            }
            .font(.callout)
        }
    }

    private func durationRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.callout.monospacedDigit())
                .frame(width: 50, alignment: .trailing)
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            .frame(width: 100)
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Behavior")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Toggle("Auto-start next session", isOn: $settings.autoStartEnabled)
                .font(.callout)
            Toggle("Play sounds", isOn: $settings.soundEnabled)
                .font(.callout)
            Toggle("Show time in menu bar", isOn: $settings.showTimeInMenuBar)
                .font(.callout)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Picker("Theme", selection: $settings.selectedTheme) {
                ForEach(ThemeIdentifier.allCases, id: \.self) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Pomodoro/Views/SettingsView.swift
git commit -m "feat: add SettingsView with duration, behavior, and theme controls"
```

---

### Task 13: Add keyboard shortcut bindings to Settings and KeyRecorderView

**Files:**
- Modify: `Pomodoro/Core/Settings.swift`
- Create: `Pomodoro/Views/KeyRecorderView.swift`
- Modify: `Pomodoro/Views/SettingsView.swift`

- [ ] **Step 1: Add shortcut bindings to Settings**

Add to `Settings`:

```swift
// In Settings class, add these properties:
var startPauseShortcut: ShortcutBinding {
    didSet { defaults.set(try? JSONEncoder().encode(startPauseShortcut), forKey: "startPauseShortcut") }
}
var skipShortcut: ShortcutBinding {
    didSet { defaults.set(try? JSONEncoder().encode(skipShortcut), forKey: "skipShortcut") }
}
var resetShortcut: ShortcutBinding {
    didSet { defaults.set(try? JSONEncoder().encode(resetShortcut), forKey: "resetShortcut") }
}

// Add at the bottom of Settings.swift:
struct ShortcutBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var displayName: String

    static let ctrlOptionP = ShortcutBinding(keyCode: 35, modifiers: 0x0800 | 0x1000, displayName: "⌃⌥P")
    static let ctrlOptionS = ShortcutBinding(keyCode: 1, modifiers: 0x0800 | 0x1000, displayName: "⌃⌥S")
    static let ctrlOptionR = ShortcutBinding(keyCode: 15, modifiers: 0x0800 | 0x1000, displayName: "⌃⌥R")
}
```

Initialize them from defaults with the default values in the `init`, same pattern as other properties.

- [ ] **Step 2: Create KeyRecorderView**

Create `Pomodoro/Views/KeyRecorderView.swift`:

```swift
import SwiftUI
import AppKit

struct KeyRecorderView: View {
    let label: String
    @Binding var shortcut: ShortcutBinding
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Button(isRecording ? "Press keys..." : shortcut.displayName) {
                isRecording = true
            }
            .buttonStyle(.bordered)
            .overlay {
                if isRecording {
                    KeyRecorderRepresentable { keyCode, modifiers, displayName in
                        shortcut = ShortcutBinding(keyCode: keyCode, modifiers: modifiers, displayName: displayName)
                        isRecording = false
                    }
                    .frame(width: 0, height: 0)
                }
            }
        }
    }
}

struct KeyRecorderRepresentable: NSViewRepresentable {
    let onRecord: (UInt32, UInt32, String) -> Void

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView(onRecord: onRecord)
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {}
}

class KeyRecorderNSView: NSView {
    let onRecord: (UInt32, UInt32, String) -> Void

    init(onRecord: @escaping (UInt32, UInt32, String) -> Void) {
        self.onRecord = onRecord
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.carbonFlags
        let keyCode = UInt32(event.keyCode)
        let displayName = event.charactersIgnoringModifiers?.uppercased() ?? ""
        let modString = Self.modifierString(event.modifierFlags)
        onRecord(keyCode, modifiers, "\(modString)\(displayName)")
    }

    static func modifierString(_ flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var carbon: UInt32 = 0
        if contains(.control) { carbon |= UInt32(controlKey) }
        if contains(.option) { carbon |= UInt32(optionKey) }
        if contains(.shift) { carbon |= UInt32(shiftKey) }
        if contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }
}
```

- [ ] **Step 3: Add keyboard shortcut section to SettingsView**

Add a new section to `SettingsView` between `behaviorSection` and `appearanceSection`:

```swift
private var shortcutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Keyboard Shortcuts")
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)

        KeyRecorderView(label: "Start / Pause", shortcut: $settings.startPauseShortcut)
        KeyRecorderView(label: "Skip", shortcut: $settings.skipShortcut)
        KeyRecorderView(label: "Reset", shortcut: $settings.resetShortcut)
    }
}
```

And add `shortcutsSection` + `Divider()` to the body between behavior and appearance sections.

- [ ] **Step 4: Verify it compiles**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add Pomodoro/Core/Settings.swift Pomodoro/Views/KeyRecorderView.swift Pomodoro/Views/SettingsView.swift
git commit -m "feat: add configurable keyboard shortcuts with key recorder UI"
```

---

### Task 14: Add notification permission banner to popover

**Files:**
- Modify: `Pomodoro/Views/TimerPopoverView.swift`
- Modify: `Pomodoro/PomodoroApp.swift`

- [ ] **Step 1: Add permission state and banner to TimerPopoverView**

Add to `TimerPopoverView`:

```swift
// Add property:
let notificationService: NotificationService
@State private var showPermissionBanner = false
@State private var permissionBannerDismissed = false

// Add to the top of timerContent VStack, before the Spacer:
if showPermissionBanner && !permissionBannerDismissed {
    notificationPermissionBanner
}

// Add this computed property:
private var notificationPermissionBanner: some View {
    HStack {
        Image(systemName: "bell.slash")
            .foregroundStyle(.orange)
        Text("Notifications disabled")
            .font(.caption)
        Spacer()
        Button("Settings") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
                NSWorkspace.shared.open(url)
            }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
        Button(action: { permissionBannerDismissed = true }) {
            Image(systemName: "xmark")
                .font(.caption2)
        }
        .buttonStyle(.plain)
    }
    .padding(8)
    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
}
```

Add an `.task` modifier on the main `VStack` to check permission:

```swift
.task {
    await notificationService.checkPermission()
    showPermissionBanner = !notificationService.isAuthorized
}
```

- [ ] **Step 2: Pass notificationService through from PomodoroApp**

Update the `TimerPopoverView` init call in `PomodoroApp` to pass `notificationService`.

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Pomodoro/Views/TimerPopoverView.swift Pomodoro/PomodoroApp.swift
git commit -m "feat: add notification permission denied banner with System Settings link"
```

---

### Task 15: Wire up PomodoroApp with services

**Files:**
- Modify: `Pomodoro/PomodoroApp.swift`

- [ ] **Step 1: Update PomodoroApp to wire everything together**

Replace `Pomodoro/PomodoroApp.swift` with:

```swift
import SwiftUI

@main
struct PomodoroApp: App {
    @State private var engine: TimerEngine
    @State private var settings: Settings
    private let notificationService: NotificationService
    private let soundService: SoundService
    private let shortcutService: GlobalShortcutService

    init() {
        let settings = Settings()
        let engine = TimerEngine(settings: settings)
        let notificationService = NotificationService()
        let soundService = SoundService(settings: settings)
        let shortcutService = GlobalShortcutService()

        engine.onSessionComplete = { sessionType in
            notificationService.notifySessionComplete(sessionType)
            soundService.playSessionComplete(sessionType)
        }

        shortcutService.register(shortcuts: [
            .startPause: .init(keyCode: settings.startPauseShortcut.keyCode, modifiers: settings.startPauseShortcut.modifiers),
            .skip: .init(keyCode: settings.skipShortcut.keyCode, modifiers: settings.skipShortcut.modifiers),
            .reset: .init(keyCode: settings.resetShortcut.keyCode, modifiers: settings.resetShortcut.modifiers)
        ]) { action in
            switch action {
            case .startPause:
                if engine.state.isRunning { engine.pause() }
                else if engine.state.isPaused { engine.resume() }
                else if engine.state == .idle { engine.start() }
            case .skip:
                engine.skip()
            case .reset:
                engine.cancel()
            }
        }

        self._engine = State(initialValue: engine)
        self._settings = State(initialValue: settings)
        self.notificationService = notificationService
        self.soundService = soundService
        self.shortcutService = shortcutService
    }

    var body: some Scene {
        MenuBarExtra {
            TimerPopoverView(engine: engine, settings: settings, notificationService: notificationService)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if settings.showTimeInMenuBar, engine.state.isRunning {
            let text = formatTime(engine.remainingSeconds)
            Label(text, systemImage: "timer")
                .labelStyle(.titleAndIcon)
        } else {
            Label("Pomodoro", systemImage: "timer")
                .labelStyle(.iconOnly)
        }
    }
}
```

- [ ] **Step 2: Build and run**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Pomodoro/PomodoroApp.swift
git commit -m "feat: wire up PomodoroApp with engine, services, and menu bar"
```

---

## Chunk 4: Global Shortcuts & Integration Tests

### Task 16: GlobalShortcutService using Carbon RegisterEventHotKey

**Files:**
- Create: `Pomodoro/Core/GlobalShortcutService.swift`

- [ ] **Step 1: Implement GlobalShortcutService**

Create `Pomodoro/Core/GlobalShortcutService.swift`:

```swift
import Carbon
import AppKit

final class GlobalShortcutService {
    struct Shortcut: Equatable {
        let keyCode: UInt32
        let modifiers: UInt32

        static let ctrlOptionP = Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey))
        static let ctrlOptionS = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey))
        static let ctrlOptionR = Shortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey))
    }

    enum Action: CaseIterable {
        case startPause
        case skip
        case reset
    }

    private var hotKeyRefs: [Action: EventHotKeyRef?] = [:]
    private var idToAction: [UInt32: Action] = [:]
    private var handler: ((Action) -> Void)?
    private var eventHandlerRef: EventHandlerRef?
    private static var instance: GlobalShortcutService?

    init() {
        GlobalShortcutService.instance = self
    }

    func register(shortcuts: [Action: Shortcut], handler: @escaping (Action) -> Void) {
        unregisterAll()
        self.handler = handler

        installCarbonHandler()

        var nextID: UInt32 = 0
        for (action, shortcut) in shortcuts {
            var hotKeyID = EventHotKeyID()
            hotKeyID.signature = OSType(0x504F4D4F) // "POMO"
            hotKeyID.id = nextID

            var hotKeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                hotKeyRefs[action] = hotKeyRef
                idToAction[nextID] = action
            }
            nextID += 1
        }
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
        idToAction.removeAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
    }

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if let action = GlobalShortcutService.instance?.idToAction[hotKeyID.id] {
                    DispatchQueue.main.async {
                        GlobalShortcutService.instance?.handler?(action)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )
        self.eventHandlerRef = handlerRef
    }

    deinit {
        unregisterAll()
    }
}
```

- [ ] **Step 2: Wire shortcuts into PomodoroApp**

Add to `PomodoroApp.init()` after the existing setup:

```swift
let shortcutService = GlobalShortcutService()
shortcutService.register(shortcuts: [
    .startPause: .ctrlOptionP,
    .skip: .ctrlOptionS,
    .reset: .ctrlOptionR
]) { action in
    switch action {
    case .startPause:
        if engine.state.isRunning { engine.pause() }
        else if engine.state.isPaused { engine.resume() }
        else if engine.state == .idle { engine.start() }
    case .skip:
        engine.skip()
    case .reset:
        engine.cancel()
    }
}
```

Store `shortcutService` as a property on `PomodoroApp` to keep it alive.

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Pomodoro/Core/GlobalShortcutService.swift Pomodoro/PomodoroApp.swift
git commit -m "feat: add GlobalShortcutService with Carbon RegisterEventHotKey"
```

---

### Task 17: Integration test — full pomodoro flow

**Files:**
- Create: `PomodoroTests/Integration/PomodoroFlowTests.swift`

- [ ] **Step 1: Write integration tests**

Create `PomodoroTests/Integration/PomodoroFlowTests.swift`:

```swift
import Testing
import Foundation
@testable import Pomodoro

@Suite("Pomodoro Flow Integration")
struct PomodoroFlowTests {
    @Test("full cycle with auto-start: work → break → work")
    func fullCycleAutoStart() {
        let mockTime = MockTimeProvider()
        let mockNotification = MockNotificationProvider()
        let mockSound = MockSoundProvider()

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = 1  // 1 min = 60 seconds
        settings.shortBreakDuration = 1
        settings.autoStartEnabled = true

        let engine = TimerEngine(settings: settings, timeProvider: mockTime)
        let notificationService = NotificationService(provider: mockNotification)
        let soundService = SoundService(provider: mockSound, settings: settings)

        engine.onSessionComplete = { type in
            notificationService.notifySessionComplete(type)
            soundService.playSessionComplete(type)
        }

        // Start work
        engine.start()
        #expect(engine.state == .running(.work))

        // Complete work
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.shortBreak))
        #expect(engine.completedPomodoros == 1)
        #expect(mockNotification.sentNotifications.count == 1)
        #expect(mockNotification.sentNotifications[0].title == "Work session complete!")
        #expect(mockSound.playedSounds.count == 1)
        #expect(mockSound.playedSounds[0] == "Glass")

        // Complete break
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.work))
        #expect(mockNotification.sentNotifications.count == 2)
        #expect(mockNotification.sentNotifications[1].title == "Break's over!")
        #expect(mockSound.playedSounds.count == 2)
        #expect(mockSound.playedSounds[1] == "Breeze")
    }

    @Test("full cycle without auto-start: work → completed → manual start break")
    func fullCycleManual() {
        let mockTime = MockTimeProvider()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = 1
        settings.shortBreakDuration = 1
        settings.autoStartEnabled = false

        let engine = TimerEngine(settings: settings, timeProvider: mockTime)

        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .completed(.work))

        engine.startNext()
        #expect(engine.state == .running(.shortBreak))
    }

    @Test("cancel mid-session preserves count then restart fresh")
    func cancelPreservesCount() {
        let mockTime = MockTimeProvider()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = 1
        settings.autoStartEnabled = true

        let engine = TimerEngine(settings: settings, timeProvider: mockTime)

        // Complete one work session
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.completedPomodoros == 1)

        // Cancel mid-break
        engine.cancel()
        #expect(engine.state == .idle)
        #expect(engine.completedPomodoros == 1) // preserved

        // Start fresh
        engine.start()
        #expect(engine.state == .running(.work))
    }

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
}
```

- [ ] **Step 2: Run integration tests**

Run: `swift test --filter PomodoroFlowTests`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add PomodoroTests/Integration/PomodoroFlowTests.swift
git commit -m "test: add integration tests for full pomodoro flow"
```

---

### Task 18: Snapshot tests for themes

**Files:**
- Create: `PomodoroSnapshotTests/ThemeSnapshotTests.swift`

- [ ] **Step 1: Write snapshot tests**

Create `PomodoroSnapshotTests/ThemeSnapshotTests.swift`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
@testable import Pomodoro

final class ThemeSnapshotTests: XCTestCase {
    let themes: [(String, ThemeContainer)] = [
        ("minimal", ThemeContainer(MinimalTheme())),
        ("glassmorphic", ThemeContainer(GlassmorphicTheme())),
        ("bold", ThemeContainer(BoldTheme()))
    ]

    let states: [(String, TimerState, SessionType)] = [
        ("idle", .idle, .work),
        ("running_work", .running(.work), .work),
        ("running_shortBreak", .running(.shortBreak), .shortBreak),
        ("paused_work", .paused(.work), .work),
        ("completed_work", .completed(.work), .work)
    ]

    let appearances: [(String, NSAppearance)] = [
        ("light", NSAppearance(named: .aqua)!),
        ("dark", NSAppearance(named: .darkAqua)!)
    ]

    func testThemeSnapshots() {
        for (themeName, theme) in themes {
            for (stateName, state, sessionType) in states {
                for (appearanceName, appearance) in appearances {
                    let view = VStack(spacing: 20) {
                        if state.isCompleted {
                            theme.completedView(sessionType: sessionType, onStartNext: {}, onCancel: {})
                        } else {
                            theme.timerView(
                                remainingSeconds: 1500,
                                totalSeconds: 1500,
                                sessionType: sessionType,
                                state: state
                            )
                            theme.controlsView(
                                state: state,
                                onStart: {}, onPause: {}, onResume: {},
                                onSkip: {}, onCancel: {}, onRestart: {}
                            )
                        }
                    }
                    .frame(width: 300, height: 350)
                    .padding()

                    let hostingController = NSHostingController(rootView: view)
                    hostingController.view.frame = NSRect(x: 0, y: 0, width: 300, height: 350)
                    hostingController.view.appearance = appearance

                    assertSnapshot(
                        of: hostingController,
                        as: .image(size: CGSize(width: 300, height: 350)),
                        named: "\(themeName)_\(stateName)_\(appearanceName)",
                        record: true // Set to false after initial recording
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run snapshot tests to record baselines**

Run: `swift test --filter ThemeSnapshotTests`
Expected: Tests PASS (recording mode creates baseline images)

- [ ] **Step 3: Set `record: false` and re-run to verify**

Change `record: true` to `record: false` in the test, then:

Run: `swift test --filter ThemeSnapshotTests`
Expected: All tests PASS (matching against baselines)

- [ ] **Step 4: Commit**

```bash
git add PomodoroSnapshotTests/
git commit -m "test: add snapshot tests for all themes in all states"
```

---

### Task 19: Run all tests and verify full coverage

- [ ] **Step 1: Run the complete test suite**

Run: `swift test`
Expected: ALL tests pass

- [ ] **Step 2: Verify test file count matches expectations**

Expected test files:
- `PomodoroTests/Core/SessionTypeTests.swift`
- `PomodoroTests/Core/TimerStateTests.swift`
- `PomodoroTests/Core/TimerEngineTests.swift`
- `PomodoroTests/Core/SettingsTests.swift`
- `PomodoroTests/Core/NotificationServiceTests.swift`
- `PomodoroTests/Core/SoundServiceTests.swift`
- `PomodoroTests/Integration/PomodoroFlowTests.swift`
- `PomodoroSnapshotTests/ThemeSnapshotTests.swift`

- [ ] **Step 3: Final commit (if any unstaged changes remain)**

```bash
git status
# Only add specific files that are part of the project, not build artifacts
git add Pomodoro/ PomodoroTests/ PomodoroSnapshotTests/ Package.swift
git commit -m "chore: verify all tests pass with full coverage"
```
