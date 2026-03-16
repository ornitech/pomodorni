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
