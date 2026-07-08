import XCTest
@testable import SpellerCore

private struct StubTransport: HTTPTransport {
    var result: Result<(Data, Int), Error>
    var captured: ((URL, [String: String], Data) -> Void)?
    func post(url: URL, headers: [String: String], body: Data) async throws -> (Data, Int) {
        captured?(url, headers, body)
        switch result {
        case .success(let pair): return pair
        case .failure(let err): throw err
        }
    }
}

/// Returns a different response per call, so we can exercise model fallback.
private final class SequenceTransport: HTTPTransport, @unchecked Sendable {
    private let responses: [(Data, Int)]
    private var index = 0
    var seenModels: [String] = []
    init(_ responses: [(Data, Int)]) { self.responses = responses }
    func post(url: URL, headers: [String: String], body: Data) async throws -> (Data, Int) {
        if let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let model = obj["model"] as? String { seenModels.append(model) }
        defer { index += 1 }
        return responses[min(index, responses.count - 1)]
    }
}

private let endpoint = URL(string: "https://example.test/v1/chat/completions")!
private let okBody = #"{"choices":[{"message":{"content":"[\"receive\"]"}}]}"#

final class SpellClientTests: XCTestCase {
    func test_suggestions_returnsParsedList() async throws {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", models: ["m"],
                                 transport: StubTransport(result: .success((Data(okBody.utf8), 200))))
        let result = try await client.suggestions(for: "recieve")
        XCTAssertEqual(result, ["receive"])
    }

    func test_suggestions_sendsAuthHeaderAndModel() async throws {
        var seenHeaders: [String: String] = [:]
        var seenBody = Data()
        let body = #"{"choices":[{"message":{"content":"[\"x\"]"}}]}"#
        let stub = StubTransport(result: .success((Data(body.utf8), 200)),
                                 captured: { _, h, b in seenHeaders = h; seenBody = b })
        let client = SpellClient(endpoint: endpoint, apiKey: "secret", models: ["mymodel"],
                                 transport: stub)
        _ = try await client.suggestions(for: "hi")
        XCTAssertEqual(seenHeaders["Authorization"], "Bearer secret")
        XCTAssertEqual(seenHeaders["Content-Type"], "application/json")
        let obj = try JSONSerialization.jsonObject(with: seenBody) as! [String: Any]
        XCTAssertEqual(obj["model"] as? String, "mymodel")
    }

    func test_suggestions_emptyInput_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", models: ["m"],
                                 transport: StubTransport(result: .success((Data(), 200))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "   ")) { error in
            XCTAssertEqual(error as? SpellClientError, .emptyInput)
        }
    }

    func test_suggestions_missingKey_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "", models: ["m"],
                                 transport: StubTransport(result: .success((Data(), 200))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .missingKey)
        }
    }

    func test_suggestions_httpError_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", models: ["m"],
                                 transport: StubTransport(result: .success((Data(), 500))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .http(500))
        }
    }

    func test_suggestions_transportFailure_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", models: ["m"],
                                 transport: StubTransport(result: .failure(URLError(.notConnectedToInternet))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .transport)
        }
    }

    func test_suggestions_singleModelRateLimited_throwsRateLimited() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", models: ["m"],
                                 transport: StubTransport(result: .success((Data(), 429))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .rateLimited)
        }
    }

    func test_suggestions_fallsBackToNextModelOn429() async throws {
        // First model 429s, second returns a good result.
        let transport = SequenceTransport([(Data(), 429), (Data(okBody.utf8), 200)])
        let client = SpellClient(endpoint: endpoint, apiKey: "k",
                                 models: ["busy", "backup"], transport: transport)
        let result = try await client.suggestions(for: "recieve")
        XCTAssertEqual(result, ["receive"])
        XCTAssertEqual(transport.seenModels, ["busy", "backup"])  // tried in order
    }

    func test_suggestions_allModelsRateLimited_throwsRateLimited() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", models: ["a", "b", "c"],
                                 transport: StubTransport(result: .success((Data(), 429))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .rateLimited)
        }
    }
}

// Small async-throws assertion helper.
func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Any,
    _ handler: (Error) -> Void
) async {
    do { _ = try await expression(); XCTFail("Expected error, got success") }
    catch { handler(error) }
}
