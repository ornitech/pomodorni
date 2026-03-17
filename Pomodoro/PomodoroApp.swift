import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let engine: TimerEngine
    private let settings: Settings
    private let notificationService: NotificationService
    private let soundService: SoundService
    private let shortcutService: GlobalShortcutService

    override init() {
        let settings = Settings()
        let engine = TimerEngine(settings: settings)
        let notificationService = NotificationService()
        let soundService = SoundService(settings: settings)
        let shortcutService = GlobalShortcutService()

        self.settings = settings
        self.engine = engine
        self.notificationService = notificationService
        self.soundService = soundService
        self.shortcutService = shortcutService

        super.init()

        engine.onSessionComplete = { [weak self] sessionType in
            self?.notificationService.notifySessionComplete(sessionType)
            self?.soundService.playSessionComplete(sessionType)
        }

        shortcutService.register(shortcuts: [
            .startPause: .ctrlOptionP,
            .skip: .ctrlOptionS,
            .reset: .ctrlOptionR
        ]) { [weak engine] action in
            guard let engine else { return }
            switch action {
            case .startPause:
                if engine.state.isRunning { engine.pause() }
                else if engine.state.isPaused { engine.resume() }
                else if engine.state == .idle { engine.start() }
            case .skip:
                engine.skip()
            case .reset:
                engine.cancel()
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item with a strong reference
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover with SwiftUI content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: TimerPopoverView(
                engine: engine,
                settings: settings,
                notificationService: notificationService
            )
        )

        // Update menu bar title periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusItemTitle()
        }
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        if settings.showTimeInMenuBar && engine.state.isRunning {
            button.title = " " + formatTime(engine.remainingSeconds)
        } else {
            button.title = ""
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
