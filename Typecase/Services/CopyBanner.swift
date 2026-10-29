import AppKit
import SwiftUI

/// A small banner that appears briefly above everything, without taking focus. Quick Lookup uses it to say that a
/// character was copied but not inserted (the window it belonged to is already gone by then).
@MainActor
enum CopyBanner {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(title: String, detail: String) {
        hideTask?.cancel()
        panel?.orderOut(nil)

        let hosting = NSHostingView(rootView: BannerView(title: title, detail: detail))
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // Bottom centre of the screen the pointer is on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 72))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        Self.panel = panel
        AccessibilityNotification.Announcement("\(title). \(detail)").post()

        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 }) {
                MainActor.assumeIsolated { panel.orderOut(nil) }
            }
        }
    }
}

private struct BannerView: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if !detail.isEmpty {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 360, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .windowBackgroundColor).opacity(0.7)) }
        }
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator) }
        .padding(8)
    }
}
