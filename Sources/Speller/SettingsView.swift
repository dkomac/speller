import SwiftUI
import SpellerCore

struct SettingsView: View {
    let settings: SettingsStore
    let secrets: SecretStore

    private enum SaveStatus { case none, saved, failed }

    @State private var apiKey: String
    @State private var model: String
    @State private var endpoint: String
    @State private var status: SaveStatus = .none

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

            HStack {
                switch status {
                case .saved:
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.callout)
                case .failed:
                    Label("Couldn't save to Keychain", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.callout)
                case .none:
                    EmptyView()
                }
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)   // Return also saves
                    .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 280)
        // Editing again clears a stale confirmation.
        .onChange(of: apiKey) { _, _ in status = .none }
        .onChange(of: model) { _, _ in status = .none }
        .onChange(of: endpoint) { _, _ in status = .none }
    }

    private func save() {
        // Trim — pasted keys often carry a trailing newline that would break the auth header.
        apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        secrets.apiKey = apiKey
        settings.model = model
        settings.endpoint = endpoint

        // Read the key back to confirm the Keychain write actually persisted.
        status = (secrets.apiKey == apiKey) ? .saved : .failed
    }
}
