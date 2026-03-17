import SwiftUI

struct TimerPopoverView: View {
    @Bindable var engine: TimerEngine
    @Bindable var settings: Settings
    let notificationService: NotificationService
    let onShowSettingsRegistration: (@escaping () -> Void) -> Void
    @State private var showSettings = false
    @State private var showPermissionBanner = false
    @State private var permissionBannerDismissed = false

    private var theme: ThemeContainer {
        ThemeContainer.theme(for: settings.selectedTheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(settings: settings, onDismiss: { showSettings = false })
            } else {
                timerContent
            }
        }
        .frame(width: 300, height: 400)
        .background {
            theme.popoverBackground(sessionType: engine.state.sessionType)
        }
        .task {
            await notificationService.checkPermission()
            showPermissionBanner = !notificationService.isAuthorized
        }
        .onAppear {
            onShowSettingsRegistration { showSettings = true }
        }
    }

    @ViewBuilder
    private var timerContent: some View {
        VStack(spacing: 20) {
            if showPermissionBanner && !permissionBannerDismissed {
                notificationPermissionBanner
            }

            Spacer()

            switch engine.state {
            case .idle:
                idleView
            case .running(let type), .paused(let type):
                theme.timerView(
                    remainingSeconds: engine.remainingSeconds,
                    totalSeconds: engine.totalSeconds,
                    sessionType: type,
                    state: engine.state
                )
                theme.controlsView(
                    state: engine.state,
                    onStart: engine.start,
                    onPause: engine.pause,
                    onResume: engine.resume,
                    onSkip: engine.skip,
                    onCancel: engine.cancel,
                    onRestart: engine.restart
                )
            case .completed(let type):
                theme.completedView(
                    sessionType: type,
                    onStartNext: engine.startNext,
                    onCancel: engine.cancel
                )
            }

            Spacer()

            footer
        }
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ready to focus?")
                .font(.title3)
            Button("Start", action: engine.start)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var footer: some View {
        HStack {
            if engine.completedPomodoros > 0 {
                Text("\(engine.completedPomodoros) pomodoro\(engine.completedPomodoros == 1 ? "" : "s") completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var notificationPermissionBanner: some View {
        HStack {
            Image(systemName: "bell.slash")
                .foregroundStyle(.orange)
            Text("Notifications disabled")
                .font(.caption)
            Spacer()
            Button("Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button(action: { permissionBannerDismissed = true }) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
