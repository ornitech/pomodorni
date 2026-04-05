import Testing
@testable import Pomodorni

@Suite("NudgeView")
struct NudgeViewTests {
    @Test("during break shows break reminder message")
    func duringBreakMessage() {
        let message = NudgeView.nudgeMessage(reason: .duringBreak, hasStartAction: false)
        #expect(message.contains("Use your break to get some time away from the screen"))
    }

    @Test("due for break with start action shows start prompt")
    func dueForBreakWithStartAction() {
        let message = NudgeView.nudgeMessage(reason: .dueForBreak, hasStartAction: true)
        #expect(message.contains("due for a break"))
        #expect(message.contains("Want to start your break now"))
    }

    @Test("due for break without start action shows step-away message")
    func dueForBreakWithoutStartAction() {
        let message = NudgeView.nudgeMessage(reason: .dueForBreak, hasStartAction: false)
        #expect(message.contains("due for a break"))
        #expect(message.contains("step away"))
    }

    @Test("no active session shows generic start message")
    func noActiveSessionMessage() {
        let message = NudgeView.nudgeMessage(reason: .noActiveSession, hasStartAction: true)
        #expect(message.contains("haven't started a session"))
    }

    @Test("during break does not mention due for break")
    func duringBreakDoesNotMentionDue() {
        let message = NudgeView.nudgeMessage(reason: .duringBreak, hasStartAction: false)
        #expect(message.contains("Use your break"))
        #expect(!message.contains("due for a break"))
    }
}
