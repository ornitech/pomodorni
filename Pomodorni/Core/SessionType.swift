import Foundation

enum SessionType: String, Codable, Equatable, Sendable {
    case work
    case shortBreak

    var displayName: String {
        switch self {
        case .work: "Work"
        case .shortBreak: "Break"
        }
    }

    func nextSessionType() -> SessionType {
        switch self {
        case .work: .shortBreak
        case .shortBreak: .work
        }
    }
}
