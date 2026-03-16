import Foundation

@Observable
final class TimerEngine {
    private(set) var state: TimerState = .idle
    private(set) var remainingSeconds: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var completedPomodoros: Int = 0

    var onSessionComplete: ((SessionType) -> Void)?

    private var intervalCounter: Int = 0
    private let settings: Settings
    private let timeProvider: TimeProvider

    init(settings: Settings, timeProvider: TimeProvider = SystemTimeProvider()) {
        self.settings = settings
        self.timeProvider = timeProvider
    }

    func start() {
        guard state == .idle else { return }
        beginSession(.work)
    }

    func pause() {
        guard case .running(let type) = state else { return }
        timeProvider.invalidate()
        state = .paused(type)
    }

    func resume() {
        guard case .paused(let type) = state else { return }
        state = .running(type)
        startTicking()
    }

    func skip() {
        guard let type = state.sessionType, state.isRunning || state.isPaused else { return }
        timeProvider.invalidate()
        completeSession(type)
    }

    func cancel() {
        timeProvider.invalidate()
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
    }

    func restart() {
        guard let type = state.sessionType, (state.isRunning || state.isPaused) else { return }
        timeProvider.invalidate()
        beginSession(type)
    }

    func startNext() {
        guard case .completed(let type) = state else { return }
        let next = type.nextSessionType(intervalCounter: intervalCounter, longBreakInterval: settings.longBreakInterval)
        beginSession(next)
    }

    // MARK: - Private

    private func beginSession(_ type: SessionType) {
        let duration = settings.durationSeconds(for: type)
        totalSeconds = duration
        remainingSeconds = duration
        state = .running(type)
        startTicking()
    }

    private func startTicking() {
        timeProvider.scheduleTick(interval: 1.0) { [weak self] in
            self?.tick()
        }
    }

    private func tick() {
        guard state.isRunning else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            guard case .running(let type) = state else { return }
            timeProvider.invalidate()
            completeSession(type)
        }
    }

    private func completeSession(_ type: SessionType) {
        if type == .work {
            completedPomodoros += 1
            intervalCounter += 1
        } else if type == .longBreak {
            intervalCounter = 0
        }

        onSessionComplete?(type)

        if settings.autoStartEnabled {
            let next = type.nextSessionType(intervalCounter: intervalCounter, longBreakInterval: settings.longBreakInterval)
            beginSession(next)
        } else {
            state = .completed(type)
            remainingSeconds = 0
        }
    }
}
