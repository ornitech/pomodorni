import Foundation
@testable import Pomodorni

final class MockActivityProvider: ActivityProvider {
    private var handler: (() -> Void)?
    var isMonitoring = false

    func startMonitoring(onActivity: @escaping () -> Void) {
        handler = onActivity
        isMonitoring = true
    }

    func stopMonitoring() {
        handler = nil
        isMonitoring = false
    }

    /// Simulate a user input event
    func simulateActivity() {
        handler?()
    }
}
