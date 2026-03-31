import Testing
@testable import Pomodorni

@Suite("NudgeView")
struct NudgeViewTests {
    @Test("during break shows break reminder message")
    func duringBreakMessage() {
        let message = NudgeView.nudgeMessage(nextSessionName: nil, duringBreak: true)
        #expect(message.contains("Use your break to get some time away from the screen"))
    }

    @Test("next session is break shows due-for-break message")
    func nextSessionBreakMessage() {
        let message = NudgeView.nudgeMessage(nextSessionName: "Break", duringBreak: false)
        #expect(message.contains("You are due for a break"))
    }

    @Test("next session is work shows generic start message")
    func nextSessionWorkMessage() {
        let message = NudgeView.nudgeMessage(nextSessionName: "Work", duringBreak: false)
        #expect(message.contains("haven't started a session"))
    }

    @Test("no next session shows generic start message")
    func noNextSessionMessage() {
        let message = NudgeView.nudgeMessage(nextSessionName: nil, duringBreak: false)
        #expect(message.contains("haven't started a session"))
    }

    @Test("duringBreak takes precedence over next session name")
    func duringBreakPrecedence() {
        let message = NudgeView.nudgeMessage(nextSessionName: "Break", duringBreak: true)
        #expect(message.contains("Use your break"))
        #expect(!message.contains("due for a break"))
    }
}
