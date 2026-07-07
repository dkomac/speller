import AppKit
import SpellerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsStore = UserDefaultsSettings()
    let secrets: SecretStore = KeychainSecretStore()

    private var menuBar: MenuBarController!
    private var hotkey: HotkeyManager!
    private let selection = SelectionService()
    private let popup = PopupController()
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        settingsWindow = SettingsWindowController(settings: settings, secrets: secrets)
        hotkey = HotkeyManager()

        menuBar.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        menuBar.onCheckSpelling = { [weak self] in self?.startFlow() }
        hotkey.onTrigger = { [weak self] in self?.startFlow() }

        hotkey.register()
        _ = SelectionService.ensureAccessibility()
    }

    /// Builds a client from the latest settings each time (picks up edits live).
    private func makeClient() -> SpellClient {
        SpellClient(
            endpoint: URL(string: settings.endpoint) ?? URL(string: Defaults.endpoint)!,
            apiKey: secrets.apiKey,
            model: settings.model,
            transport: URLSessionTransport())
    }

    private func startFlow() {
        Task { @MainActor in
            let word = await selection.captureSelection()
            let client = makeClient()
            popup.show(
                initialWord: word,
                load: { query in
                    do { return .suggestions(try await client.suggestions(for: query)) }
                    catch SpellClientError.missingKey { return .needsAPIKey }
                    catch { return .failed }
                },
                onAccept: { [weak self] chosen in
                    Task { await self?.selection.replaceSelection(with: chosen) }
                })
        }
    }
}
