import Foundation
@testable import Pomodoro

final class MockTimeProvider: TimeProvider {
    private var handler: (() -> Void)?
    var isScheduled = false
    var tickCount = 0

    func scheduleTick(interval: TimeInterval, handler: @escaping () -> Void) {
        self.handler = handler
        isScheduled = true
    }

    func invalidate() {
        handler = nil
        isScheduled = false
    }

    /// Simulate `count` timer ticks
    func fire(times count: Int = 1) {
        for _ in 0..<count {
            tickCount += 1
            handler?()
        }
    }
}
