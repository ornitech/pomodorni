import AppKit
import SwiftUI

final class AlertPanel {
    private var panel: NSPanel?
    private var autoDismissTimer: Timer?

    func show(
        for sessionType: SessionType,
        nextSessionName: String,
        style: AlertStyle,
        autoStarted: Bool,
        statusItemWindow: NSWindow?,
        onStartNext: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        guard style != .none else { return }
        dismiss()

        let overlay = AlertOverlayView(
            sessionType: sessionType,
            nextSessionName: nextSessionName,
            alertStyle: style,
            autoStarted: autoStarted,
            onStartNext: { [weak self] in
                onStartNext()
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                onDismiss()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: overlay)
        hostingView.setFrameSize(hostingView.fittingSize)

        let contentSize = hostingView.fittingSize
        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = false
        newPanel.isReleasedWhenClosed = false
        newPanel.contentView = hostingView

        let origin = panelOrigin(for: style, panelSize: contentSize, statusItemWindow: statusItemWindow)
        newPanel.setFrameOrigin(origin)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel

        if autoStarted {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Positioning

    private func panelOrigin(for style: AlertStyle, panelSize: NSSize, statusItemWindow: NSWindow?) -> NSPoint {
        switch style {
        case .pill:
            return pillOrigin(panelSize: panelSize, statusItemWindow: statusItemWindow)
        case .centered:
            return centeredOrigin(panelSize: panelSize)
        case .corner:
            return cornerOrigin(panelSize: panelSize)
        case .none:
            return .zero
        }
    }

    private func pillOrigin(panelSize: NSSize, statusItemWindow: NSWindow?) -> NSPoint {
        guard let statusFrame = statusItemWindow?.frame,
              let screen = statusItemWindow?.screen ?? NSScreen.main else {
            return centeredOrigin(panelSize: panelSize)
        }

        let x = statusFrame.midX - panelSize.width / 2
        let y = statusFrame.minY - panelSize.height - 4

        let clampedX = min(max(x, screen.visibleFrame.minX + 4), screen.visibleFrame.maxX - panelSize.width - 4)
        return NSPoint(x: clampedX, y: y)
    }

    private func centeredOrigin(panelSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let frame = screen.visibleFrame
        return NSPoint(
            x: frame.midX - panelSize.width / 2,
            y: frame.midY - panelSize.height / 2
        )
    }

    private func cornerOrigin(panelSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let frame = screen.visibleFrame
        return NSPoint(
            x: frame.maxX - panelSize.width - 16,
            y: frame.maxY - panelSize.height - 16
        )
    }
}
