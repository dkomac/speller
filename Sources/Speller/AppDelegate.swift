import AppKit
import SpellerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsStore = UserDefaultsSettings()
    let secrets: SecretStore = KeychainSecretStore()
    private(set) var menuBar: MenuBarController!
    private(set) var hotkey: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        hotkey = HotkeyManager()
        hotkey.onTrigger = { NSLog("Speller: hotkey fired") }   // replaced in Task 13
        hotkey.register()
    }
}
