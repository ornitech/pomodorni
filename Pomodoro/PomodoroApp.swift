import SwiftUI

@main
struct PomodoroApp: App {
    @State private var engine: TimerEngine
    @State private var settings: Settings
    private let notificationService: NotificationService
    private let soundService: SoundService

    init() {
        let settings = Settings()
        let engine = TimerEngine(settings: settings)
        let notificationService = NotificationService()
        let soundService = SoundService(settings: settings)

        engine.onSessionComplete = { sessionType in
            notificationService.notifySessionComplete(sessionType)
            soundService.playSessionComplete(sessionType)
        }

        self._engine = State(initialValue: engine)
        self._settings = State(initialValue: settings)
        self.notificationService = notificationService
        self.soundService = soundService
    }

    var body: some Scene {
        MenuBarExtra {
            TimerPopoverView(engine: engine, settings: settings, notificationService: notificationService)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if settings.showTimeInMenuBar, engine.state.isRunning {
            let text = formatTime(engine.remainingSeconds)
            Label(text, systemImage: "timer")
                .labelStyle(.titleAndIcon)
        } else {
            Label("Pomodoro", systemImage: "timer")
                .labelStyle(.iconOnly)
        }
    }
}
