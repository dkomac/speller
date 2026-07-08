import AppKit
import SwiftUI

/// A borderless panel that can still become key (so it receives keystrokes).
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PopupController {
    private var panel: KeyablePanel?

    func show(initialWord: String?,
              load: @escaping (String) async -> SpellLoadOutcome,
              onAccept: @escaping (String) -> Void) {
        close()

        let view = SuggestionView(
            initialQuery: initialWord ?? "",
            load: load,
            onAccept: { [weak self] word in self?.close(); onAccept(word) },
            onCancel: { [weak self] in self?.close() }
        )

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear     // SwiftUI draws the rounded material background
        panel.hasShadow = true

        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize]   // panel shrinks/grows to fit content
        panel.contentViewController = hosting

        positionNearMouse(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    /// Place the popup just below-right of the cursor, clamped to the visible screen.
    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let size = panel.frame.size
        var x = mouse.x + 8
        var y = mouse.y - 8            // below the cursor (screen origin is bottom-left)
        if let vis = screen?.visibleFrame {
            x = min(max(x, vis.minX + 8), vis.maxX - size.width - 8)
            y = min(max(y, vis.minY + size.height + 8), vis.maxY - 8)
        }
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
