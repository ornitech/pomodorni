import SwiftUI

struct ThemeContainer {
    private let _timerView: (Int, Int, SessionType, TimerState) -> AnyView
    private let _controlsView: (TimerState, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void, @escaping () -> Void) -> AnyView
    private let _completedView: (SessionType, @escaping () -> Void, @escaping () -> Void) -> AnyView
    private let _popoverBackground: (SessionType?) -> AnyView

    let id: ThemeIdentifier
    let name: String

    init<T: PomodoroTheme>(_ theme: T) {
        self.id = theme.id
        self.name = theme.name
        self._timerView = { AnyView(theme.timerView(remainingSeconds: $0, totalSeconds: $1, sessionType: $2, state: $3)) }
        self._controlsView = { AnyView(theme.controlsView(state: $0, onStart: $1, onPause: $2, onResume: $3, onSkip: $4, onCancel: $5, onRestart: $6)) }
        self._completedView = { AnyView(theme.completedView(sessionType: $0, onStartNext: $1, onCancel: $2)) }
        self._popoverBackground = { AnyView(theme.popoverBackground(sessionType: $0)) }
    }

    func timerView(remainingSeconds: Int, totalSeconds: Int, sessionType: SessionType, state: TimerState) -> some View {
        _timerView(remainingSeconds, totalSeconds, sessionType, state)
    }

    func controlsView(state: TimerState, onStart: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void, onSkip: @escaping () -> Void, onCancel: @escaping () -> Void, onRestart: @escaping () -> Void) -> some View {
        _controlsView(state, onStart, onPause, onResume, onSkip, onCancel, onRestart)
    }

    func completedView(sessionType: SessionType, onStartNext: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        _completedView(sessionType, onStartNext, onCancel)
    }

    func popoverBackground(sessionType: SessionType?) -> some View {
        _popoverBackground(sessionType)
    }

    static let allThemes: [ThemeContainer] = [
        ThemeContainer(MinimalTheme()),
        ThemeContainer(GlassmorphicTheme()),
        ThemeContainer(BoldTheme())
    ]

    static func theme(for id: ThemeIdentifier) -> ThemeContainer {
        allThemes.first { $0.id == id } ?? ThemeContainer(MinimalTheme())
    }
}
