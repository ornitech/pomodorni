import Testing
import Foundation
@testable import Pomodorni

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
}
