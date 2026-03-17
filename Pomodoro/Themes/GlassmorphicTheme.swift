import SwiftUI

struct GlassmorphicTheme: PomodoroTheme {
    let id = ThemeIdentifier.glassmorphic
    let name = "Glassmorphic"

    private func accentColor(for sessionType: SessionType) -> Color {
        switch sessionType {
        case .work: .blue
        case .shortBreak: .orange
        case .longBreak: .purple
        }
    }

    private func gradient(for sessionType: SessionType) -> LinearGradient {
        let color = accentColor(for: sessionType)
        return LinearGradient(
            colors: [color.opacity(0.3), color.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                    lineWidth: 8,
                    trackColor: .white.opacity(0.15),
                    progressColor: accentColor(for: sessionType)
                )
                .frame(width: 140, height: 140)
                .shadow(color: accentColor(for: sessionType).opacity(0.3), radius: 8)

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 42, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(gradient(for: sessionType))
                )
        }
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
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
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    private func glassButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
