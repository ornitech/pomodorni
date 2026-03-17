import SwiftUI

struct MinimalTheme: PomodoroTheme {
    let id = ThemeIdentifier.minimal
    let name = "Minimal"

    func popoverBackground(sessionType: SessionType?) -> some View {
        EmptyView()
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
        VStack(spacing: 16) {
            Text(sessionType.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 6,
                    trackColor: Color(.separatorColor),
                    progressColor: .indigo
                )
                .frame(width: 130, height: 130)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 20) {
            switch state {
            case .idle:
                iconButton("play.fill", action: onStart)
            case .running:
                iconButton("pause.fill", action: onPause)
                iconButton("forward.fill", action: onSkip)
                iconButton("arrow.counterclockwise", action: onRestart)
                iconButton("xmark", action: onCancel)
            case .paused:
                iconButton("play.fill", action: onResume)
                iconButton("forward.fill", action: onSkip)
                iconButton("arrow.counterclockwise", action: onRestart)
                iconButton("xmark", action: onCancel)
            case .completed:
                EmptyView()
            }
        }
        .font(.title2)
    }

    func completedView(sessionType: SessionType, nextSessionName: String, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("\(sessionType.displayName) complete!")
                .font(.headline)
            HStack(spacing: 16) {
                Button("Start \(nextSessionName)", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                Button("Done", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(.indigo)
        }
        .buttonStyle(.plain)
    }
}
