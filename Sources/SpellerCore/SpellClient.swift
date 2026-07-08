import Foundation

public enum SpellClientError: Error, Equatable {
    case emptyInput
    case missingKey
    case http(Int)
    case rateLimited
    case transport
}

public struct SpellClient {
    private let endpoint: URL
    private let apiKey: String
    private let models: [String]
    private let transport: HTTPTransport

    public init(endpoint: URL, apiKey: String, models: [String], transport: HTTPTransport) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.models = models
        self.transport = transport
    }

    /// Tries each model in order, returning the first non-empty result. Free models are
    /// frequently rate-limited (HTTP 429) at the provider; on 429 or an unusable response
    /// we fall through to the next model. If every model is rate-limited, throws
    /// `.rateLimited` so the UI can tell the user to retry rather than "couldn't reach".
    public func suggestions(for input: String, context: String? = nil) async throws -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpellClientError.emptyInput }
        guard !apiKey.isEmpty else { throw SpellClientError.missingKey }
        guard !models.isEmpty else { throw SpellClientError.transport }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ]

        var sawRateLimit = false
        var lastError: SpellClientError = .transport

        for model in models {
            let body = SpellRequest.body(model: model, input: trimmed, context: context)
            do {
                let (data, status) = try await transport.post(url: endpoint, headers: headers, body: body)
                if status == 429 {
                    sawRateLimit = true
                    lastError = .rateLimited
                    continue   // this model's provider is busy; try the next one
                }
                guard (200...299).contains(status) else {
                    lastError = .http(status)
                    continue
                }
                let parsed = SuggestionParser.parseResponseBody(data)
                if !parsed.isEmpty { return parsed }
                lastError = .http(status)   // 2xx but nothing parseable; try the next model
            } catch {
                lastError = .transport
            }
        }
        throw sawRateLimit ? SpellClientError.rateLimited : lastError
    }
}
