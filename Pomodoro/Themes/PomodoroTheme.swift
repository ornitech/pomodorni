import SwiftUI

protocol PomodoroTheme {
    associatedtype TimerBody: View
    associatedtype ControlsBody: View
    associatedtype CompletedBody: View
    associatedtype BackgroundBody: View

    var id: ThemeIdentifier { get }
    var name: String { get }

    @ViewBuilder func popoverBackground(sessionType: SessionType?) -> BackgroundBody

    @ViewBuilder func timerView(
        remainingSeconds: Int,
        totalSeconds: Int,
        sessionType: SessionType,
        state: TimerState
    ) -> TimerBody

    @ViewBuilder func controlsView(
        state: TimerState,
        onStart: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRestart: @escaping () -> Void
    ) -> ControlsBody

    @ViewBuilder func completedView(
        sessionType: SessionType,
        onStartNext: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> CompletedBody
}
