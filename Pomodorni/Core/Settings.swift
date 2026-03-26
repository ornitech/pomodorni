import Foundation

enum AlertStyle: String, CaseIterable {
    case pill
    case centered
    case corner
    case none
}

@Observable
final class Settings {
    private let defaults: UserDefaults

    private var _alertStyle: AlertStyle
    private var _workDuration: Int
    private var _shortBreakDuration: Int
    private var _activityNudgeDelay: Int

    var alertStyle: AlertStyle {
        get { _alertStyle }
        set {
            _alertStyle = newValue
            defaults.set(newValue.rawValue, forKey: "alertStyle")
        }
    }
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
    var checkForUpdatesAutomatically: Bool {
        didSet { defaults.set(checkForUpdatesAutomatically, forKey: "checkForUpdatesAutomatically") }
    }
    var activityNudgeEnabled: Bool {
        didSet { defaults.set(activityNudgeEnabled, forKey: "activityNudgeEnabled") }
    }
    var activityNudgeDelay: Int {
        get { _activityNudgeDelay }
        set {
            _activityNudgeDelay = newValue.clamped(to: 1...30)
            defaults.set(_activityNudgeDelay, forKey: "activityNudgeDelay")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let alertRaw = defaults.string(forKey: "alertStyle") ?? AlertStyle.centered.rawValue
        self._alertStyle = AlertStyle(rawValue: alertRaw) ?? .centered
        self._workDuration = defaults.object(forKey: "workDuration") as? Int ?? 25
        self._shortBreakDuration = defaults.object(forKey: "shortBreakDuration") as? Int ?? 5
        self.autoStartEnabled = defaults.object(forKey: "autoStartEnabled") as? Bool ?? false
        self.soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        self.showTimeInMenuBar = defaults.object(forKey: "showTimeInMenuBar") as? Bool ?? true
        let themeRaw = defaults.string(forKey: "selectedTheme") ?? ThemeIdentifier.minimal.rawValue
        self.selectedTheme = ThemeIdentifier(rawValue: themeRaw) ?? .minimal
        self.checkForUpdatesAutomatically = defaults.object(forKey: "checkForUpdatesAutomatically") as? Bool ?? true
        self.activityNudgeEnabled = defaults.object(forKey: "activityNudgeEnabled") as? Bool ?? true
        self._activityNudgeDelay = (defaults.object(forKey: "activityNudgeDelay") as? Int ?? 1).clamped(to: 1...30)
    }

    func durationSeconds(for sessionType: SessionType) -> Int {
        switch sessionType {
        case .work: workDuration * 60
        case .shortBreak: shortBreakDuration * 60
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
