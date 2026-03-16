import SwiftUI

@main
struct PomodoroApp: App {
    var body: some Scene {
        MenuBarExtra("Pomodoro", systemImage: "timer") {
            Text("Pomodoro Timer")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
