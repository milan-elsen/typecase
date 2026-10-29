import AppKit
import SwiftUI

/// A panel that can take keyboard input without making Typecase the active app. The app that was in front stays in
/// front and keeps its text cursor, so Return can type the character straight into it. (A normal window would
/// activate Typecase first, which takes the cursor away.)
private final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        AppModel.shared.closeQuickLookup(returnToPreviousApp: true)
    }
}

/// Hosts the SwiftUI Quick Lookup view and keeps the panel as tall as the view wants to be, growing downwards.
private final class QuickHostingView<Content: View>: NSHostingView<Content> {
    weak var panel: NSPanel?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in self?.fitPanel() }
    }

    func fitPanel() {
        guard let panel else { return }
        layoutSubtreeIfNeeded()
        let size = fittingSize
        guard size.width > 0, size.height > 0, abs(panel.frame.height - size.height) > 0.5 || abs(panel.frame.width - size.width) > 0.5 else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height   // keep the top edge where it is
        frame.size = size
        panel.setFrame(frame, display: true)
    }
}

/// Owns the Quick Lookup panel: shows it, hides it, and remembers where the user dragged it.
@MainActor
final class QuickLookupPanelController {
    private var panel: QuickPanel?
    private var lastTopLeft: NSPoint?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(model: AppModel) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        // A fresh view each time resets the query and the selection.
        let host = QuickHostingView(rootView: QuickLookupView().environment(model))
        host.panel = panel
        panel.contentView = host
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        panel.setContentSize(size)

        if !panel.isVisible { place(panel, size: size) }
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        guard let panel else { return }
        lastTopLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        panel.orderOut(nil)
        panel.contentView = nil   // tears the SwiftUI view down
    }

    private func makePanel() -> QuickPanel {
        // `.nonactivatingPanel` has to be part of the style mask from the start.
        let panel = QuickPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func place(_ panel: NSPanel, size: NSSize) {
        if let topLeft = lastTopLeft, NSScreen.screens.contains(where: { $0.frame.contains(topLeft) }) {
            panel.setFrameTopLeftPoint(topLeft)
            return
        }
        // Centred horizontally, in the upper third of the screen the pointer is on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        panel.setFrameTopLeftPoint(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - frame.height * 0.2))
    }
}
