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
