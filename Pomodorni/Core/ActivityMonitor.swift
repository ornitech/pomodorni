// Pomodorni/Core/ActivityMonitor.swift
import Foundation

@Observable
final class ActivityMonitor {
    var onNudge: (() -> Void)?
    var onDismissNudge: (() -> Void)?

    private(set) var isMonitoring = false
    private(set) var isNudging = false
    private(set) var isSilenced = false

    private let settings: Settings
    private let activityProvider: ActivityProvider
    private let timeProvider: TimeProvider

    private var hasActivitySinceLastCheck = false
    private var activityWindow: [Bool] = []
    private var idleCheckCount = 0
    private var snoozeChecksRemaining = 0
    private var nudgeOnFirstActivity = false

    static let checkInterval: TimeInterval = 30
    static let idleThresholdChecks = 1
    static let snoozeChecks = 10

    init(settings: Settings, activityProvider: ActivityProvider, timeProvider: TimeProvider = SystemTimeProvider()) {
        self.settings = settings
        self.activityProvider = activityProvider
        self.timeProvider = timeProvider
    }

    func startMonitoring() {
        guard settings.activityNudgeEnabled, !isSilenced else { return }
        stopInternal()
        isMonitoring = true
        hasActivitySinceLastCheck = false
        activityWindow = []
        activityProvider.startMonitoring { [weak self] in
            self?.hasActivitySinceLastCheck = true
        }
        timeProvider.scheduleTick(interval: Self.checkInterval) { [weak self] in
            self?.check()
        }
    }

    func stopMonitoring() {
        stopInternal()
    }

    func snooze() {
        isNudging = false
        isMonitoring = false
        activityProvider.stopMonitoring()
        hasActivitySinceLastCheck = false
        activityWindow = []
        snoozeChecksRemaining = Self.snoozeChecks
        nudgeOnFirstActivity = true
    }

    func silenceUntilNextSession() {
        isSilenced = true
        stopInternal()
    }

    func resetSilence() {
        isSilenced = false
    }

    // MARK: - Private

    private func stopInternal() {
        isMonitoring = false
        isNudging = false
        activityProvider.stopMonitoring()
        timeProvider.invalidate()
        activityWindow = []
        hasActivitySinceLastCheck = false
        idleCheckCount = 0
        snoozeChecksRemaining = 0
        nudgeOnFirstActivity = false
    }

    private func check() {
        if snoozeChecksRemaining > 0 {
            snoozeChecksRemaining -= 1
            if snoozeChecksRemaining == 0 {
                isMonitoring = true
                activityProvider.startMonitoring { [weak self] in
                    self?.hasActivitySinceLastCheck = true
                }
            }
            return
        }

        if isNudging {
            if hasActivitySinceLastCheck {
                idleCheckCount = 0
            } else {
                idleCheckCount += 1
            }
            hasActivitySinceLastCheck = false

            if idleCheckCount >= Self.idleThresholdChecks {
                isNudging = false
                isMonitoring = true
                idleCheckCount = 0
                activityWindow = []
                onDismissNudge?()
            }
            return
        }

        if isMonitoring {
            activityWindow.append(hasActivitySinceLastCheck)
            hasActivitySinceLastCheck = false

            let requiredWindows = max(1, settings.activityNudgeDelay * 2)

            if nudgeOnFirstActivity {
                nudgeOnFirstActivity = false
                if activityWindow.last == true {
                    fireNudge()
                    return
                }
            }

            if activityWindow.count > requiredWindows {
                activityWindow = Array(activityWindow.suffix(requiredWindows))
            }

            if activityWindow.count >= requiredWindows &&
                activityWindow.suffix(requiredWindows).allSatisfy({ $0 }) {
                fireNudge()
            }
        }
    }

    private func fireNudge() {
        isMonitoring = false
        isNudging = true
        idleCheckCount = 0
        activityWindow = []
        onNudge?()
    }
}
