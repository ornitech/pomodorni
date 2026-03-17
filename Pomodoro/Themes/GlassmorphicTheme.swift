import SwiftUI

struct GlassmorphicTheme: PomodoroTheme {
    let id = ThemeIdentifier.glassmorphic
    let name = "Glassmorphic"

    func popoverBackground(sessionType: SessionType?) -> some View {
        let type = sessionType ?? .work
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [accentColor(for: type).opacity(0.15), accentColor(for: type).opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func accentColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: .blue
        case .shortBreak: .orange
        case .longBreak: .purple
        }
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
        VStack(spacing: 12) {
            Text(sessionType.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 8,
                    trackColor: .white.opacity(0.15),
                    progressColor: accentColor(for: sessionType)
                )
                .frame(width: 130, height: 130)
                .shadow(color: accentColor(for: sessionType).opacity(0.3), radius: 8)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            switch state {
            case .idle:
                glassButton("play.fill", action: onStart)
            case .running:
                glassButton("pause.fill", action: onPause)
                glassButton("forward.fill", action: onSkip)
                glassButton("arrow.counterclockwise", action: onRestart)
                glassButton("xmark", action: onCancel)
            case .paused:
                glassButton("play.fill", action: onResume)
                glassButton("forward.fill", action: onSkip)
                glassButton("arrow.counterclockwise", action: onRestart)
                glassButton("xmark", action: onCancel)
            case .completed:
                EmptyView()
            }
        }
    }

    func completedView(sessionType: SessionType, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(accentColor(for: sessionType))
            Text("\(sessionType.displayName) complete!")
                .font(.headline)
            HStack(spacing: 16) {
                Button("Start Next", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor(for: sessionType))
                Button("Done", action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func glassButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
