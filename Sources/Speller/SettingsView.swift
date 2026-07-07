import SwiftUI
import SpellerCore

struct SettingsView: View {
    let settings: SettingsStore
    let secrets: SecretStore

    @State private var apiKey: String
    @State private var model: String
    @State private var endpoint: String

    init(settings: SettingsStore, secrets: SecretStore) {
        self.settings = settings
        self.secrets = secrets
        _apiKey = State(initialValue: secrets.apiKey)
        _model = State(initialValue: settings.model)
        _endpoint = State(initialValue: settings.endpoint)
    }

    var body: some View {
        Form {
            Section("Provider") {
                SecureField("API key", text: $apiKey)
                TextField("Model id", text: $model)
                TextField("Endpoint", text: $endpoint)
            }
            Text("Default provider is OpenRouter's free tier. Paste an OpenRouter API key and use a free model id (ending in :free).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 240)
        .onChange(of: apiKey) { _, v in secrets.apiKey = v }
        .onChange(of: model) { _, v in settings.model = v }
        .onChange(of: endpoint) { _, v in settings.endpoint = v }
    }
}
