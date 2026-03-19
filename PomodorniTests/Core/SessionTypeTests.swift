import Testing
@testable import Pomodorni

@Suite("SessionType")
struct SessionTypeTests {
    @Test("has two cases")
    func cases() {
        let allCases: [SessionType] = [.work, .shortBreak]
        #expect(allCases.count == 2)
    }

    @Test("display names are correct")
    func displayNames() {
        #expect(SessionType.work.displayName == "Work")
        #expect(SessionType.shortBreak.displayName == "Break")
    }

    @Test("next session after work is break")
    func nextAfterWork() {
        #expect(SessionType.work.nextSessionType() == .shortBreak)
    }

    @Test("next session after break is work")
    func nextAfterBreak() {
        #expect(SessionType.shortBreak.nextSessionType() == .work)
    }
}
