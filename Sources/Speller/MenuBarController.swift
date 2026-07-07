import AppKit

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    /// Called when the user picks "Check spelling…" from the menu (wired in Task 13).
    var onCheckSpelling: (() -> Void)?
    /// Called when the user picks "Settings…" (wired in Task 12).
    var onOpenSettings: (() -> Void)?

    override init() {
        super.init()
        statusItem.button?.title = "🔤"
        let menu = NSMenu()
        // AppKit's addItem(withTitle:action:keyEquivalent:) returns the created NSMenuItem.
        menu.addItem(withTitle: "Check spelling…", action: #selector(check), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Speller", action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func check() { onCheckSpelling?() }
    @objc private func settings() { onOpenSettings?() }
}
