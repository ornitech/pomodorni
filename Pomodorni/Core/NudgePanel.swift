import AppKit
import SwiftUI

final class NudgePanel {
    private var panel: NSPanel?

    func show(
        reason: NudgeReason = .noActiveSession,
        nextSessionName: String?,
        statusItemWindow: NSWindow?,
        onStart: (() -> Void)? = nil,
        onSnooze: @escaping () -> Void,
        onSilence: @escaping () -> Void
    ) {
        dismiss()

        let view = NudgeView(
            reason: reason,
            nextSessionName: nextSessionName,
            onStart: onStart.map { start in
                { [weak self] in
                    start()
                    self?.dismiss()
                }
            },
            onSnooze: { [weak self] in
                onSnooze()
                self?.dismiss()
            },
            onSilence: { [weak self] in
                onSilence()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
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

        let origin = pillOrigin(panelSize: contentSize, statusItemWindow: statusItemWindow)
        newPanel.setFrameOrigin(origin)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Positioning

    private func pillOrigin(panelSize: NSSize, statusItemWindow: NSWindow?) -> NSPoint {
        guard let statusFrame = statusItemWindow?.frame,
              let screen = statusItemWindow?.screen ?? NSScreen.main else {
            guard let screen = NSScreen.main else { return .zero }
            let frame = screen.visibleFrame
            return NSPoint(x: frame.midX - panelSize.width / 2, y: frame.midY - panelSize.height / 2)
        }

        let x = statusFrame.midX - panelSize.width / 2
        let y = statusFrame.minY - panelSize.height - 4

        let clampedX = min(max(x, screen.visibleFrame.minX + 4), screen.visibleFrame.maxX - panelSize.width - 4)
        return NSPoint(x: clampedX, y: y)
    }
}
