import SwiftUI

struct NudgeView: View {
    let nextSessionName: String?
    let duringBreak: Bool
    let onStart: (() -> Void)?
    let onSnooze: () -> Void
    let onSilence: () -> Void

    var message: String {
        Self.nudgeMessage(nextSessionName: nextSessionName, duringBreak: duringBreak)
    }

    static func nudgeMessage(nextSessionName: String?, duringBreak: Bool) -> String {
        if duringBreak {
            return "You've started a break, but it looks like you are working. Use your break to get some time away from the screen. It is more important than you think!"
        }
        if nextSessionName?.lowercased().contains("break") == true {
            return "You are due for a break, but it looks like you are working. Want to start your break now?"
        }
        return "It looks like you're working but haven't started a session. Want to start one now?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: duringBreak ? "cup.and.saucer.fill" : "deskclock.fill")
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
                Button(duringBreak ? "Dismiss" : "Silence until next session", action: onSilence)
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
