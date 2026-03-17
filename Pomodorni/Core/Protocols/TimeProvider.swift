import Foundation

protocol TimeProvider: AnyObject {
    /// Schedule a repeating tick. Calls `handler` every `interval` seconds.
    func scheduleTick(interval: TimeInterval, handler: @escaping () -> Void)
    /// Stop all scheduled ticks.
    func invalidate()
}

/// Production timer using DispatchSourceTimer with App Nap prevention.
final class SystemTimeProvider: TimeProvider {
    private var timer: DispatchSourceTimer?
    private var activity: NSObjectProtocol?

    func scheduleTick(interval: TimeInterval, handler: @escaping () -> Void) {
        invalidate()
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Pomodoro timer active"
        )
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler(handler: handler)
        timer.resume()
        self.timer = timer
    }

    func invalidate() {
        timer?.cancel()
        timer = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
