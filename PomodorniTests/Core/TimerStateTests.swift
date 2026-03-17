import Testing
@testable import Pomodorni

@Suite("TimerState")
struct TimerStateTests {
    @Test("idle has no session type")
    func idleSession() {
        let state = TimerState.idle
        #expect(state.sessionType == nil)
    }

    @Test("running exposes session type")
    func runningSession() {
        let state = TimerState.running(.work)
        #expect(state.sessionType == .work)
    }

    @Test("paused exposes session type")
    func pausedSession() {
        let state = TimerState.paused(.shortBreak)
        #expect(state.sessionType == .shortBreak)
    }

    @Test("completed exposes session type")
    func completedSession() {
        let state = TimerState.completed(.longBreak)
        #expect(state.sessionType == .longBreak)
    }

    @Test("isRunning is true only for running state")
    func isRunning() {
        #expect(TimerState.running(.work).isRunning)
        #expect(!TimerState.idle.isRunning)
        #expect(!TimerState.paused(.work).isRunning)
        #expect(!TimerState.completed(.work).isRunning)
    }

    @Test("isPaused is true only for paused state")
    func isPaused() {
        #expect(TimerState.paused(.work).isPaused)
        #expect(!TimerState.idle.isPaused)
        #expect(!TimerState.running(.work).isPaused)
    }
}
