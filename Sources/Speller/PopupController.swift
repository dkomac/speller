import AppKit
import SwiftUI

/// A borderless panel that can still become key (so it receives keystrokes).
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PopupController {
    private var panel: KeyablePanel?
    private var resignObserver: NSObjectProtocol?

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
        // Force SwiftUI layout so the panel has its real size BEFORE we position it —
        // otherwise it's 0×0 at placement time and grows from the wrong corner.
        hosting.view.layoutSubtreeIfNeeded()
        let fitting = hosting.view.fittingSize
        if fitting.width > 1, fitting.height > 1 { panel.setContentSize(fitting) }

        positionNearMouse(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // Close as soon as the popup loses focus (user clicked elsewhere / switched app).
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.close() }
    }

    /// Place the popup just below-right of the cursor, clamped to the visible screen.
    /// Reliable in every app (unlike selection geometry, which macOS exposes only
    /// unreliably and not at all in Electron apps); and since the user selects with
    /// the mouse, the cursor is right next to the word.
    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let size = panel.frame.size
        var x = mouse.x + 8
        var y = mouse.y - 8
        if let vis = screen?.visibleFrame {
            x = min(max(x, vis.minX + 8), vis.maxX - size.width - 8)
            y = min(max(y, vis.minY + size.height + 8), vis.maxY - 8)
        }
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    func close() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}
