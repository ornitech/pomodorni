import SwiftUI

struct BoldTheme: PomodoroTheme {
    let id = ThemeIdentifier.bold
    let name = "Bold"

    func popoverBackground(sessionType: SessionType?) -> some View {
        EmptyView()
    }

    private func primaryColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: .red
        case .shortBreak: .green
        case .longBreak: .blue
        }
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
        let color = primaryColor(for: sessionType)
        VStack(spacing: 16) {
            Text(sessionType.displayName)
                .font(.headline.bold())
                .foregroundStyle(color)

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 12,
                    trackColor: color.opacity(0.2),
                    progressColor: color
                )
                .frame(width: 130, height: 130)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            switch state {
            case .idle:
                boldButton("play.fill", color: .red, action: onStart)
            case .running(let type):
                boldButton("pause.fill", color: primaryColor(for: type), action: onPause)
                boldButton("forward.fill", color: primaryColor(for: type), action: onSkip)
                boldButton("arrow.counterclockwise", color: primaryColor(for: type), action: onRestart)
                boldButton("xmark", color: .gray, action: onCancel)
            case .paused(let type):
                boldButton("play.fill", color: primaryColor(for: type), action: onResume)
                boldButton("forward.fill", color: primaryColor(for: type), action: onSkip)
                boldButton("arrow.counterclockwise", color: primaryColor(for: type), action: onRestart)
                boldButton("xmark", color: .gray, action: onCancel)
            case .completed:
                EmptyView()
            }
        }
    }

    func completedView(sessionType: SessionType, nextSessionName: String, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        let color = primaryColor(for: sessionType)
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(color)
                .scaleEffect(1.1)
            Text("\(sessionType.displayName) complete!")
                .font(.headline.bold())
                .foregroundStyle(color)
            HStack(spacing: 16) {
                Button("Start \(nextSessionName)", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                Button("Done", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func boldButton(_ systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
