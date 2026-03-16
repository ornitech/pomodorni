import Foundation

@Observable
final class Settings {
    private let defaults: UserDefaults

    private var _workDuration: Int
    private var _shortBreakDuration: Int
    private var _longBreakDuration: Int
    private var _longBreakInterval: Int

    var workDuration: Int {
        get { _workDuration }
        set {
            _workDuration = newValue.clamped(to: 1...60)
            defaults.set(_workDuration, forKey: "workDuration")
        }
    }
    var shortBreakDuration: Int {
        get { _shortBreakDuration }
        set {
            _shortBreakDuration = newValue.clamped(to: 1...30)
            defaults.set(_shortBreakDuration, forKey: "shortBreakDuration")
        }
    }
    var longBreakDuration: Int {
        get { _longBreakDuration }
        set {
            _longBreakDuration = newValue.clamped(to: 1...60)
            defaults.set(_longBreakDuration, forKey: "longBreakDuration")
        }
    }
    var longBreakInterval: Int {
        get { _longBreakInterval }
        set {
            _longBreakInterval = newValue.clamped(to: 1...10)
            defaults.set(_longBreakInterval, forKey: "longBreakInterval")
        }
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
        self._workDuration = defaults.object(forKey: "workDuration") as? Int ?? 25
        self._shortBreakDuration = defaults.object(forKey: "shortBreakDuration") as? Int ?? 5
        self._longBreakDuration = defaults.object(forKey: "longBreakDuration") as? Int ?? 15
        self._longBreakInterval = defaults.object(forKey: "longBreakInterval") as? Int ?? 4
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
