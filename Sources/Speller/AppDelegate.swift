import AppKit
import SpellerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsStore = UserDefaultsSettings()
    let secrets: SecretStore = KeychainSecretStore()
    private(set) var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
    }
}
