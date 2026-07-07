import AppKit
import SwiftUI

/// A panel that can become key even though it is borderless, so it receives key events.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PopupController {
    private var panel: KeyablePanel?

    func show(initialWord: String?,
              load: @escaping (String) async -> [String],
              onAccept: @escaping (String) -> Void) {
        close()

        let view = SuggestionView(
            initialQuery: initialWord ?? "",
            load: load,
            onAccept: { [weak self] word in self?.close(); onAccept(word) },
            onCancel: { [weak self] in self?.close() }
        )

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
