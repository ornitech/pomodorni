import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    // Two status items: timerItem (variable, text only) sits to the LEFT
    // of iconItem (fixed, icon only). Popover always anchors to iconItem.
    private var iconItem: NSStatusItem!
    private var timerItem: NSStatusItem!
    private var popover: NSPopover!
    private let engine: TimerEngine
    private let settings: Settings
    private let notificationService: NotificationService
    private let soundService: SoundService
    private let shortcutService: GlobalShortcutService
    var showSettingsCallback: (() -> Void)?

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
        // Icon item: fixed square width, never changes position.
        // Created FIRST so it appears to the RIGHT in the menu bar.
        iconItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = iconItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Timer item: variable width, shows countdown text.
        // Created SECOND so it appears to the LEFT of the icon.
        timerItem = NSStatusBar.system.statusItem(withLength: 0)
        timerItem.isVisible = false

        // Create popover with SwiftUI content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: TimerPopoverView(
                engine: engine,
                settings: settings,
                notificationService: notificationService,
                onShowSettingsRegistration: { [weak self] callback in
                    self?.showSettingsCallback = callback
                }
            )
        )

        // Request notification permission on first launch
        Task {
            await notificationService.requestPermission()
        }

        // Update timer text periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimerDisplay()
        }
    }

    private func updateTimerDisplay() {
        if settings.showTimeInMenuBar && engine.state.isRunning {
            let timeString = formatTime(engine.remainingSeconds)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
            timerItem.button?.attributedTitle = NSAttributedString(string: timeString, attributes: attributes)
            timerItem.length = NSStatusItem.variableLength
            timerItem.isVisible = true
        } else {
            timerItem.isVisible = false
            timerItem.length = 0
        }
    }

    @objc private func statusItemClicked() {
        guard iconItem.button != nil,
              let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = iconItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pomodoro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        iconItem.menu = menu
        iconItem.button?.performClick(nil)
        iconItem.menu = nil
    }

    @objc private func openSettings() {
        guard let button = iconItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        showSettingsCallback?()
    }
}
