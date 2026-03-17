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
        // Create status bar item with a strong reference
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

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

        // Update menu bar title periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusItemTitle()
        }
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        if settings.showTimeInMenuBar && engine.state.isRunning {
            let timeString = formatTime(engine.remainingSeconds) + " "
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
            button.attributedTitle = NSAttributedString(string: timeString, attributes: attributes)
            button.imagePosition = .imageRight
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
        }
    }

    @objc private func statusItemClicked() {
        guard statusItem.button != nil,
              let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Anchor on the icon itself. The icon is always at the right
            // edge of the button (imagePosition = .imageRight).
            let imageWidth = button.image?.size.width ?? 18
            let iconCenterX = button.bounds.maxX - imageWidth / 2
            let anchorRect = NSRect(
                x: iconCenterX,
                y: button.bounds.minY,
                width: 1,
                height: button.bounds.height
            )
            popover.show(relativeTo: anchorRect, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pomodoro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Remove menu after it closes so left-click still opens the popover
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        // Open the popover and show settings
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        showSettingsCallback?()
    }
}
