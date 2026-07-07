import Foundation

public enum SpellClientError: Error, Equatable {
    case emptyInput
    case missingKey
    case http(Int)
    case transport
}

public struct SpellClient {
    private let endpoint: URL
    private let apiKey: String
    private let model: String
    private let transport: HTTPTransport

    public init(endpoint: URL, apiKey: String, model: String, transport: HTTPTransport) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.transport = transport
    }

    public func suggestions(for input: String) async throws -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpellClientError.emptyInput }
        guard !apiKey.isEmpty else { throw SpellClientError.missingKey }

        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ]
        let body = SpellRequest.body(model: model, input: trimmed)

        let (data, status): (Data, Int)
        do {
            (data, status) = try await transport.post(url: endpoint, headers: headers, body: body)
        } catch {
            throw SpellClientError.transport
        }
        guard (200...299).contains(status) else { throw SpellClientError.http(status) }
        return SuggestionParser.parseResponseBody(data)
    }
}
