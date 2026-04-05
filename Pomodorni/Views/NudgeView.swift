import SwiftUI

enum NudgeReason: Equatable {
    case duringBreak
    case dueForBreak
    case noActiveSession
}

struct NudgeView: View {
    let reason: NudgeReason
    let nextSessionName: String?
    let onStart: (() -> Void)?
    let onSnooze: () -> Void
    let onSilence: () -> Void

    var message: String {
        Self.nudgeMessage(reason: reason, hasStartAction: onStart != nil)
    }

    static func nudgeMessage(reason: NudgeReason, hasStartAction: Bool) -> String {
        switch reason {
        case .duringBreak:
            return "You've started a break, but it looks like you are working. Use your break to get some time away from the screen. It is more important than you think!"
        case .dueForBreak:
            if hasStartAction {
                return "You are due for a break, but it looks like you are working. Want to start your break now?"
            }
            return "You're due for a break, but it looks like you're still working. Take a moment to step away from the screen!"
        case .noActiveSession:
            return "It looks like you're working but haven't started a session. Want to start one now?"
        }
    }

    private var iconName: String {
        switch reason {
        case .duringBreak: "cup.and.saucer.fill"
        case .dueForBreak: "cup.and.saucer"
        case .noActiveSession: "deskclock.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text(message)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let onStart {
                    Button(nextSessionName.map { "Start \($0)" } ?? "Start", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                }
                Spacer()
                Button("Remind me in 5 minutes", action: onSnooze)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button(reason == .duringBreak ? "Dismiss" : "Silence until next session", action: onSilence)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 440)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
