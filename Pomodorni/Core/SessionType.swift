import Foundation

enum SessionType: String, Codable, Equatable, Sendable {
    case work
    case shortBreak
    case longBreak

    var displayName: String {
        switch self {
        case .work: "Work"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    func nextSessionType(intervalCounter: Int, longBreakInterval: Int) -> SessionType {
        switch self {
        case .work:
            return intervalCounter >= longBreakInterval ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }
}
