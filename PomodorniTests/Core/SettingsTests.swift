import Testing
import Foundation
@testable import Pomodorni

@Suite("Settings")
struct SettingsTests {
    @Test("default values are correct")
    func defaults() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        #expect(settings.workDuration == 25)
        #expect(settings.shortBreakDuration == 5)
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

    @Test func checkForUpdatesAutomaticallyDefaultsToTrue() {
        let defaults = UserDefaults(suiteName: "test-updates-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        #expect(settings.checkForUpdatesAutomatically == true)
    }

    @Test func checkForUpdatesAutomaticallyPersists() {
        let suite = "test-updates-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = Settings(defaults: defaults)
        settings.checkForUpdatesAutomatically = false
        let settings2 = Settings(defaults: defaults)
        #expect(settings2.checkForUpdatesAutomatically == false)
    }

    @Test("duration in seconds helper")
    func durationSeconds() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        #expect(settings.durationSeconds(for: .work) == 1500)
        #expect(settings.durationSeconds(for: .shortBreak) == 300)
    }
}
