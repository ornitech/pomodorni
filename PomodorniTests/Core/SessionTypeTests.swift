import Testing
@testable import Pomodorni

@Suite("SessionType")
struct SessionTypeTests {
    @Test("has three cases")
    func cases() {
        let allCases: [SessionType] = [.work, .shortBreak, .longBreak]
        #expect(allCases.count == 3)
    }

    @Test("display names are correct")
    func displayNames() {
        #expect(SessionType.work.displayName == "Work")
        #expect(SessionType.shortBreak.displayName == "Short Break")
        #expect(SessionType.longBreak.displayName == "Long Break")
    }

    @Test("next session after work is short break by default")
    func nextAfterWork() {
        #expect(SessionType.work.nextSessionType(intervalCounter: 1, longBreakInterval: 4) == .shortBreak)
    }

    @Test("next session after work triggers long break at interval")
    func nextAfterWorkLongBreak() {
        #expect(SessionType.work.nextSessionType(intervalCounter: 4, longBreakInterval: 4) == .longBreak)
    }

    @Test("next session after short break is work")
    func nextAfterShortBreak() {
        #expect(SessionType.shortBreak.nextSessionType(intervalCounter: 1, longBreakInterval: 4) == .work)
    }

    @Test("next session after long break is work")
    func nextAfterLongBreak() {
        #expect(SessionType.longBreak.nextSessionType(intervalCounter: 0, longBreakInterval: 4) == .work)
    }
}
