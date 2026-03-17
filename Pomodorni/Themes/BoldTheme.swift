import SwiftUI

struct BoldTheme: PomodoroTheme {
    let id = ThemeIdentifier.bold
    let name = "Bold"

    // Owl palette
    private static let owlRed = Color(red: 0.83, green: 0.17, blue: 0.12)
    private static let owlOrange = Color(red: 0.94, green: 0.47, blue: 0.19)
    private static let owlNavy = Color(red: 0.17, green: 0.16, blue: 0.37)
    private static let owlAmber = Color(red: 0.96, green: 0.63, blue: 0.26)

    func popoverBackground(sessionType: SessionType?) -> some View {
        let (top, bottom) = gradientColors(for: sessionType)
        LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func gradientColors(for sessionType: SessionType?) -> (Color, Color) {
        switch sessionType {
        case .work, .none:
            (Self.owlRed, Self.owlOrange)
        case .shortBreak:
            (Self.owlNavy, Self.owlNavy.opacity(0.85))
        case .longBreak:
            (Self.owlAmber, Self.owlOrange)
        }
    }

    private func primaryColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: Self.owlRed
        case .shortBreak: Self.owlNavy
        case .longBreak: Self.owlAmber
        }
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
        VStack(spacing: 16) {
            Text(sessionType.displayName)
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.9))

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 12,
                    trackColor: .white.opacity(0.2),
                    progressColor: .white
                )
                .frame(width: 130, height: 130)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            switch state {
            case .idle:
                boldButton("play.fill", action: onStart)
            case .running:
                boldButton("pause.fill", action: onPause)
                boldButton("forward.fill", action: onSkip)
                boldButton("arrow.counterclockwise", action: onRestart)
                boldButton("xmark", action: onCancel)
            case .paused:
                boldButton("play.fill", action: onResume)
                boldButton("forward.fill", action: onSkip)
                boldButton("arrow.counterclockwise", action: onRestart)
                boldButton("xmark", action: onCancel)
            case .completed:
                EmptyView()
            }
        }
    }

    func completedView(sessionType: SessionType, nextSessionName: String, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .scaleEffect(1.1)
            Text("\(sessionType.displayName) complete!")
                .font(.headline.bold())
                .foregroundStyle(.white)
            HStack(spacing: 16) {
                Button("Start \(nextSessionName)", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.25))
                Button("Done", action: onCancel)
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
        }
    }

    private func boldButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.25), in: Circle())
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
