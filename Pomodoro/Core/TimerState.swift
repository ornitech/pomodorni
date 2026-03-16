import Foundation

enum TimerState: Equatable, Sendable {
    case idle
    case running(SessionType)
    case paused(SessionType)
    case completed(SessionType)

    var sessionType: SessionType? {
        switch self {
        case .idle: nil
        case .running(let type), .paused(let type), .completed(let type): type
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}
