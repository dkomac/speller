import Foundation

public enum SpellRequest {
    public static let systemPrompt = """
    You are a spelling assistant for a dyslexic user. The user's input is EITHER a \
    misspelled word/phrase (often spelled phonetically), OR describing a word they \
    can't recall. Decide which it is. If surrounding text is provided, detect its \
    language and return corrections in that same language. Respond with ONLY a JSON \
    array of up to 5 correctly-spelled candidate words or short phrases, ranked \
    most-likely first. Include multiple entries when several spellings are valid \
    (e.g. practice/practise). Output nothing except the JSON array — no prose, no code fences.
    """

    public static func body(model: String, input: String, context: String? = nil) -> Data {
        let userContent: String
        if let context, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userContent = "Surrounding text: \"\(context)\"\n\nWord to correct: \(input)"
        } else {
            userContent = input
        }
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent],
            ],
            "temperature": 0,
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
}
