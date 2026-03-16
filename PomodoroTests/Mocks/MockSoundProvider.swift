@testable import Pomodoro

final class MockSoundProvider: SoundProvider {
    var playedSounds: [String] = []

    func play(systemSound name: String) {
        playedSounds.append(name)
    }
}
