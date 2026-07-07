import AppKit
import SwiftUI
import SpellerCore

final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsStore
    private let secrets: SecretStore

    init(settings: SettingsStore, secrets: SecretStore) {
        self.settings = settings
        self.secrets = secrets
    }

    func show() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let view = SettingsView(settings: settings, secrets: secrets)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Speller Settings"
        w.contentView = NSHostingView(rootView: view)
        w.center()
        w.isReleasedWhenClosed = false
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
