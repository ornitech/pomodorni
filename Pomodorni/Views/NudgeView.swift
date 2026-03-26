import SwiftUI

struct NudgeView: View {
    let onStart: () -> Void
    let onSnooze: () -> Void
    let onSilence: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "deskclock.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text("It looks like you're working but haven't started a session. Want to start one now?")
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button("Start", action: onStart)
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
