import AppKit
import ApplicationServices
import SpellerCore

final class SelectionService {
    private let clipboard = ClipboardService(SystemPasteboard())

    /// Prompts for Accessibility permission if not yet granted. Returns current trust state.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Simulates ⌘C, reads the copied text, then restores the user's clipboard
    /// immediately so cancel/error paths never leave the clipboard clobbered.
    /// Returns the copied text (or nil if nothing was selected).
    func captureSelection() async -> String? {
        clipboard.snapshotAndClear()
        postCommandKey(0x08) // 'c'
        try? await Task.sleep(nanoseconds: 120_000_000) // 120ms for the app to place text
        let selected = clipboard.currentString()
        clipboard.restore()
        return (selected?.isEmpty == false) ? selected : nil
    }

    /// Snapshots the clipboard, places `word`, simulates ⌘V, then restores the clipboard.
    func replaceSelection(with word: String) async {
        clipboard.snapshotAndClear()
        clipboard.placeForPaste(word)
        postCommandKey(0x09) // 'v'
        try? await Task.sleep(nanoseconds: 120_000_000)
        clipboard.restore()
    }

    private func postCommandKey(_ keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
