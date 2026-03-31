import SwiftUI

struct NudgeView: View {
    let nextSessionName: String?
    let onStart: () -> Void
    let onSnooze: () -> Void
    let onSilence: () -> Void

    private var isBreak: Bool {
        nextSessionName?.lowercased().contains("break") == true
    }

    private var message: String {
        if isBreak {
            return "You are due for a break, but it looks like you are working. Want to start your break now?"
        }
        return "It looks like you're working but haven't started a session. Want to start one now?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "deskclock.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text(message)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(nextSessionName.map { "Start \($0)" } ?? "Start", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
                Spacer()
                Button("Remind me in 5 minutes", action: onSnooze)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Silence until next session", action: onSilence)
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
