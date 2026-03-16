import Testing
import Foundation
@testable import Pomodoro

@Suite("TimerEngine")
struct TimerEngineTests {
    let mockTime = MockTimeProvider()

    func makeEngine(autoStart: Bool = false, workDuration: Int = 1, shortBreakDuration: Int = 1, longBreakDuration: Int = 1, longBreakInterval: Int = 4) -> TimerEngine {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = workDuration
        settings.shortBreakDuration = shortBreakDuration
        settings.longBreakDuration = longBreakDuration
        settings.longBreakInterval = longBreakInterval
        settings.autoStartEnabled = autoStart
        return TimerEngine(settings: settings, timeProvider: mockTime)
    }

    // MARK: - Initial state
    @Test("starts in idle state")
    func initialState() {
        let engine = makeEngine()
        #expect(engine.state == .idle)
        #expect(engine.remainingSeconds == 0)
        #expect(engine.completedPomodoros == 0)
    }

    // MARK: - Start
    @Test("start transitions from idle to running work")
    func startFromIdle() {
        let engine = makeEngine()
        engine.start()
        #expect(engine.state == .running(.work))
        #expect(engine.remainingSeconds == 60)
        #expect(engine.totalSeconds == 60)
        #expect(mockTime.isScheduled)
    }

    @Test("start does nothing if already running")
    func startWhileRunning() {
        let engine = makeEngine()
        engine.start()
        engine.start()
        #expect(engine.state == .running(.work))
    }

    // MARK: - Countdown
    @Test("tick decrements remaining seconds")
    func tickDecrement() {
        let engine = makeEngine()
        engine.start()
        mockTime.fire(times: 1)
        #expect(engine.remainingSeconds == 59)
    }

    // MARK: - Session completion (auto-start OFF)
    @Test("work session completes to completed state when auto-start disabled")
    func workCompletesNoAutoStart() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .completed(.work))
        #expect(engine.completedPomodoros == 1)
    }

    // MARK: - Session completion (auto-start ON)
    @Test("work session auto-starts short break")
    func workAutoStartsBreak() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .running(.shortBreak))
        #expect(engine.completedPomodoros == 1)
        #expect(engine.remainingSeconds == 60)
    }

    @Test("short break auto-starts next work session")
    func breakAutoStartsWork() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60)  // finish work
        mockTime.fire(times: 60)  // finish break
        #expect(engine.state == .running(.work))
    }

    // MARK: - Long break logic
    @Test("long break triggers after N work sessions")
    func longBreakAfterInterval() {
        let engine = makeEngine(autoStart: true, longBreakInterval: 2)
        engine.start()
        mockTime.fire(times: 60)  // work 1 done -> short break
        mockTime.fire(times: 60)  // short break done -> work 2
        mockTime.fire(times: 60)  // work 2 done -> long break (interval reached)
        #expect(engine.state == .running(.longBreak))
    }

    @Test("interval counter resets after long break")
    func intervalResetsAfterLongBreak() {
        let engine = makeEngine(autoStart: true, longBreakInterval: 2)
        engine.start()
        mockTime.fire(times: 60)  // work 1 -> short break
        mockTime.fire(times: 60)  // short break -> work 2
        mockTime.fire(times: 60)  // work 2 -> long break
        mockTime.fire(times: 60)  // long break -> work 3
        #expect(engine.state == .running(.work))
        mockTime.fire(times: 60)  // work 3 -> short break (not long, counter reset)
        #expect(engine.state == .running(.shortBreak))
    }

    // MARK: - Pause / Resume
    @Test("pause transitions running to paused")
    func pause() {
        let engine = makeEngine()
        engine.start()
        engine.pause()
        #expect(engine.state == .paused(.work))
        #expect(!mockTime.isScheduled)
    }

    @Test("resume transitions paused to running")
    func resume() {
        let engine = makeEngine()
        engine.start()
        let remaining = engine.remainingSeconds
        engine.pause()
        engine.resume()
        #expect(engine.state == .running(.work))
        #expect(engine.remainingSeconds == remaining)
        #expect(mockTime.isScheduled)
    }

    // MARK: - Cancel
    @Test("cancel returns to idle and preserves pomodoro count")
    func cancel() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60)
        engine.cancel()
        #expect(engine.state == .idle)
        #expect(engine.completedPomodoros == 1)
        #expect(!mockTime.isScheduled)
    }

    @Test("cancel from paused state")
    func cancelWhilePaused() {
        let engine = makeEngine()
        engine.start()
        engine.pause()
        engine.cancel()
        #expect(engine.state == .idle)
    }

    // MARK: - Skip
    @Test("skip during work transitions to completed work")
    func skipWork() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        engine.skip()
        #expect(engine.state == .completed(.work))
        #expect(engine.completedPomodoros == 1)
    }

    @Test("skip during break with auto-start transitions to running work")
    func skipBreak() {
        let engine = makeEngine(autoStart: true)
        engine.start()
        mockTime.fire(times: 60)
        engine.skip()
        #expect(engine.state == .running(.work))
    }

    // MARK: - Restart
    @Test("restart resets timer to full duration, same session type")
    func restart() {
        let engine = makeEngine()
        engine.start()
        mockTime.fire(times: 30)
        #expect(engine.remainingSeconds == 30)
        engine.restart()
        #expect(engine.state == .running(.work))
        #expect(engine.remainingSeconds == 60)
    }

    // MARK: - Start next from completed
    @Test("startNext from completed work begins break")
    func startNextFromCompleted() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .completed(.work))
        engine.startNext()
        #expect(engine.state == .running(.shortBreak))
    }

    @Test("startNext is no-op from non-completed state")
    func startNextFromRunning() {
        let engine = makeEngine()
        engine.start()
        engine.startNext()
        #expect(engine.state == .running(.work))
    }

    // MARK: - Completion callback
    @Test("onSessionComplete callback fires when session ends")
    func completionCallback() {
        let engine = makeEngine(autoStart: false)
        var completedType: SessionType?
        engine.onSessionComplete = { type in completedType = type }
        engine.start()
        mockTime.fire(times: 60)
        #expect(completedType == .work)
    }

    // MARK: - Edge cases
    @Test("skip during break without auto-start goes to completed")
    func skipBreakNoAutoStart() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60)
        engine.startNext()
        engine.skip()
        #expect(engine.state == .completed(.shortBreak))
    }

    @Test("skip while paused works")
    func skipWhilePaused() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        engine.pause()
        engine.skip()
        #expect(engine.state == .completed(.work))
        #expect(engine.completedPomodoros == 1)
    }

    @Test("restart at 1 second remaining resets to full duration")
    func restartAtOneSecond() {
        let engine = makeEngine()
        engine.start()
        mockTime.fire(times: 59)
        #expect(engine.remainingSeconds == 1)
        engine.restart()
        #expect(engine.remainingSeconds == 60)
        #expect(engine.state == .running(.work))
    }

    @Test("double pause is no-op")
    func doublePause() {
        let engine = makeEngine()
        engine.start()
        engine.pause()
        engine.pause()
        #expect(engine.state == .paused(.work))
    }

    @Test("double resume is no-op")
    func doubleResume() {
        let engine = makeEngine()
        engine.start()
        engine.resume()
        #expect(engine.state == .running(.work))
    }

    @Test("start from completed state is no-op")
    func startFromCompleted() {
        let engine = makeEngine(autoStart: false)
        engine.start()
        mockTime.fire(times: 60)
        #expect(engine.state == .completed(.work))
        engine.start()
        #expect(engine.state == .completed(.work))
    }

    @Test("settings changes mid-session do not affect running timer")
    func settingsMidSession() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.workDuration = 1
        settings.autoStartEnabled = false
        let engine = TimerEngine(settings: settings, timeProvider: mockTime)

        engine.start()
        #expect(engine.totalSeconds == 60)
        mockTime.fire(times: 10)

        settings.workDuration = 2
        #expect(engine.remainingSeconds == 50)
        #expect(engine.totalSeconds == 60)
    }
}
