import AppKit

protocol ActivityProvider: AnyObject {
    func startMonitoring(onActivity: @escaping () -> Void)
    func stopMonitoring()
}

/// Production activity provider using global NSEvent monitoring.
final class SystemActivityProvider: ActivityProvider {
    private var monitor: Any?

    func startMonitoring(onActivity: @escaping () -> Void) {
        stopMonitoring()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .keyDown]) { _ in
            onActivity()
        }
    }

    func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
