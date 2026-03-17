import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private let engine: TimerEngine
    private let settings: Settings
    private let notificationService: NotificationService
    private let soundService: SoundService
    private let shortcutService: GlobalShortcutService
    private let alertPanel = AlertPanel()
    var showSettingsCallback: (() -> Void)?
    private var eventMonitor: Any?

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
            guard let self else { return }
            self.notificationService.notifySessionComplete(sessionType)
            self.soundService.playSessionComplete(sessionType)
            self.showAlert(for: sessionType)
        }

        shortcutService.register(shortcuts: [
            .startPause: .ctrlOptionP,
            .skip: .ctrlOptionS,
            .reset: .ctrlOptionR
        ]) { [weak self, weak engine] action in
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
                self?.alertPanel.dismiss()
                self?.resetStatusIcon()
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodorni")
            button.image?.isTemplate = true
            button.imagePosition = .imageRight
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Custom panel instead of NSPopover — gives full control over positioning
        let contentSize = NSSize(width: 300, height: 400)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false

        let hostingView = NSHostingView(
            rootView: TimerPopoverView(
                engine: engine,
                settings: settings,
                notificationService: notificationService,
                onShowSettingsRegistration: { [weak self] callback in
                    self?.showSettingsCallback = callback
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        panel.contentView = hostingView

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

        // Swap icon to alert variant when session is completed
        let iconName = engine.state.isCompleted ? "timer.circle.fill" : "timer"
        let newImage = NSImage(systemSymbolName: iconName, accessibilityDescription: "Pomodorni")
        newImage?.isTemplate = true
        button.image = newImage
    }

    /// Calculate the panel origin so it's centered horizontally on the
    /// status item icon and positioned just below the menu bar.
    /// Uses screen coordinates from the button's window frame.
    private func panelOrigin() -> NSPoint {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            return .zero
        }

        let statusRect = buttonWindow.frame
        let imageWidth = button.image?.size.width ?? 16

        // Icon is at the right edge of the status item (imageRight).
        // The right edge of the status item window is fixed on screen.
        let iconCenterX = statusRect.maxX - imageWidth / 2

        // Center panel horizontally on the icon
        let panelWidth = panel.frame.width
        var x = iconCenterX - panelWidth / 2

        // Keep panel on screen
        let screenRight = screen.visibleFrame.maxX
        let screenLeft = screen.visibleFrame.minX
        x = min(x, screenRight - panelWidth - 4)
        x = max(x, screenLeft + 4)

        // Position just below the menu bar
        let y = statusRect.minY - panel.frame.height - 4

        return NSPoint(x: x, y: y)
    }

    private func showAlert(for sessionType: SessionType) {
        let autoStarted = settings.autoStartEnabled
        alertPanel.show(
            for: sessionType,
            nextSessionName: engine.nextSessionName,
            style: settings.alertStyle,
            autoStarted: autoStarted,
            statusItemWindow: statusItem.button?.window,
            onStartNext: { [weak self] in
                self?.engine.startNext()
                self?.resetStatusIcon()
            },
            onDismiss: { }
        )
    }

    private func resetStatusIcon() {
        guard let button = statusItem?.button else { return }
        let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodorni")
        image?.isTemplate = true
        button.image = image
    }

    @objc private func statusItemClicked() {
        guard statusItem.button != nil,
              let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        alertPanel.dismiss()
        resetStatusIcon()

        panel.setFrameOrigin(panelOrigin())
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Close when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pomodorni", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        if !panel.isVisible {
            openPanel()
        }
        showSettingsCallback?()
    }
}
