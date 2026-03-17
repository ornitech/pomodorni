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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
            button.image?.isTemplate = true
            // Always imageRight so the icon stays at the fixed right edge
            // of the status item. Timer text grows to the left.
            button.imagePosition = .imageRight
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

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

        Task {
            await notificationService.requestPermission()
        }

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimerDisplay()
        }
    }

    private func updateTimerDisplay() {
        guard let button = statusItem?.button else { return }
        if settings.showTimeInMenuBar && engine.state.isRunning {
            let timeString = formatTime(engine.remainingSeconds) + " "
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
            button.attributedTitle = NSAttributedString(string: timeString, attributes: attributes)
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }
        // Always keep imageRight — never switch to imageOnly
    }

    /// The rect within the button where the icon sits.
    /// With imageRight, the icon is pinned to the right edge.
    /// The right edge of a status item is fixed on screen (items grow left),
    /// so this rect maps to the same screen position regardless of button width.
    private func iconRect(in button: NSStatusBarButton) -> NSRect {
        let imageWidth = button.image?.size.width ?? 16
        return NSRect(
            x: button.bounds.maxX - imageWidth,
            y: button.bounds.minY,
            width: imageWidth,
            height: button.bounds.height
        )
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
            popover.show(relativeTo: iconRect(in: button), of: button, preferredEdge: .minY)
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
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: iconRect(in: button), of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        showSettingsCallback?()
    }
}
