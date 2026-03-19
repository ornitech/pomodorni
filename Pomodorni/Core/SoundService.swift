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
        case .shortBreak: "Breeze"
        }
        provider.play(systemSound: soundName)
    }
}

final class SystemSoundProvider: SoundProvider {
    func play(systemSound name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
