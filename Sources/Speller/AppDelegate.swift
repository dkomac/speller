import AppKit
import SpellerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsStore = UserDefaultsSettings()
    let secrets: SecretStore = FileSecretStore()

    private var menuBar: MenuBarController!
    private var hotkey: HotkeyManager!
    private let selection = SelectionService()
    private let contextReader = ContextReader()
    private let popup = PopupController()
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppMenu.install()   // enables ⌘V/⌘C etc. in text fields (accessory apps have no menu bar)
        menuBar = MenuBarController()
        settingsWindow = SettingsWindowController(settings: settings, secrets: secrets)
        hotkey = HotkeyManager()

        menuBar.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        menuBar.onCheckSpelling = { [weak self] in self?.startFlow() }
        hotkey.onTrigger = { [weak self] in self?.startFlow() }

        hotkey.register()
        _ = SelectionService.ensureAccessibility()
    }

    /// Free models are often rate-limited; if the chosen one is busy we fall through
    /// to these. Chosen to span DIFFERENT vendors/providers (Google, OpenAI-OSS,
    /// NVIDIA, small Meta) so they're rarely all throttled at once — Llama-free and
    /// Qwen-free both route through the same provider (Venice), which is why the old
    /// list didn't help.
    private let fallbackModels = [
        "nvidia/nemotron-3-nano-30b-a3b:free",   // NVIDIA infra — responding when others are throttled
        "google/gemma-4-31b-it:free",
        "openai/gpt-oss-120b:free",
        "meta-llama/llama-3.2-3b-instruct:free",
    ]

    /// Builds a client from the latest settings each time (picks up edits live).
    private func makeClient() -> SpellClient {
        let primary = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        let models = ([primary] + fallbackModels).filter { !$0.isEmpty && seen.insert($0).inserted }
        return SpellClient(
            endpoint: URL(string: settings.endpoint) ?? URL(string: Defaults.endpoint)!,
            apiKey: secrets.apiKey,
            models: models,
            transport: URLSessionTransport())
    }

    private func startFlow() {
        // The app the user was in when they triggered — we must reactivate it before
        // pasting, or ⌘V lands nowhere (our popup has the focus by then).
        let previousApp = NSWorkspace.shared.frontmostApplication
        Task { @MainActor in
            let word = await selection.captureSelection()
            // Best-effort surrounding text for language detection (gated by the setting).
            let context = settings.useContext ? contextReader.surroundingText() : nil
            let client = makeClient()
            popup.show(
                initialWord: word,
                load: { query in
                    do { return .suggestions(try await client.suggestions(for: query, context: context)) }
                    catch SpellClientError.missingKey { return .needsAPIKey }
                    catch SpellClientError.rateLimited { return .rateLimited }
                    catch { return .failed }
                },
                onAccept: { [weak self] chosen in
                    Task { @MainActor in
                        previousApp?.activate()                       // focus back to their app
                        try? await Task.sleep(nanoseconds: 150_000_000) // let the switch settle
                        await self?.selection.replaceSelection(with: chosen)
                    }
                })
        }
    }
}
