import Foundation

public enum SuggestionParser {
    private struct ChatResponse: Decodable {
        struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
        let choices: [Choice]
    }

    /// Extracts up to 5 trimmed, non-empty candidate strings from the assistant's text.
    public static func parseContent(_ content: String) -> [String] {
        guard let start = content.firstIndex(of: "["),
              let end = content.lastIndex(of: "]"),
              start < end else { return [] }
        let jsonSlice = String(content[start...end])
        guard let data = jsonSlice.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)
            .map { $0 }
    }

    /// Decodes an OpenAI-compatible response body, then parses the message content.
    public static func parseResponseBody(_ data: Data) -> [String] {
        guard let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let first = response.choices.first else { return [] }
        return parseContent(first.message.content)
    }
}
