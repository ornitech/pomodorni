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

    // MARK: - Task 3: Sustained Activity Triggers Nudge

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

    // MARK: - Task 4: Snooze Behavior

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

    // MARK: - Task 5: Silence Until Next Session

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

    // MARK: - Task 6: Auto-Dismiss on Idle

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

    // MARK: - Task 7: Stop When Engine Starts

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
}
