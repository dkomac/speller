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

private let endpoint = URL(string: "https://example.test/v1/chat/completions")!

final class SpellClientTests: XCTestCase {
    func test_suggestions_returnsParsedList() async throws {
        let body = #"{"choices":[{"message":{"content":"[\"receive\"]"}}]}"#
        let client = SpellClient(endpoint: endpoint, apiKey: "k", model: "m",
                                 transport: StubTransport(result: .success((Data(body.utf8), 200))))
        let result = try await client.suggestions(for: "recieve")
        XCTAssertEqual(result, ["receive"])
    }

    func test_suggestions_sendsAuthHeaderAndModel() async throws {
        var seenHeaders: [String: String] = [:]
        var seenBody = Data()
        let body = #"{"choices":[{"message":{"content":"[\"x\"]"}}]}"#
        let stub = StubTransport(result: .success((Data(body.utf8), 200)),
                                 captured: { _, h, b in seenHeaders = h; seenBody = b })
        let client = SpellClient(endpoint: endpoint, apiKey: "secret", model: "mymodel",
                                 transport: stub)
        _ = try await client.suggestions(for: "hi")
        XCTAssertEqual(seenHeaders["Authorization"], "Bearer secret")
        XCTAssertEqual(seenHeaders["Content-Type"], "application/json")
        let obj = try JSONSerialization.jsonObject(with: seenBody) as! [String: Any]
        XCTAssertEqual(obj["model"] as? String, "mymodel")
    }

    func test_suggestions_emptyInput_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", model: "m",
                                 transport: StubTransport(result: .success((Data(), 200))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "   ")) { error in
            XCTAssertEqual(error as? SpellClientError, .emptyInput)
        }
    }

    func test_suggestions_missingKey_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "", model: "m",
                                 transport: StubTransport(result: .success((Data(), 200))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .missingKey)
        }
    }

    func test_suggestions_httpError_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", model: "m",
                                 transport: StubTransport(result: .success((Data(), 429))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .http(429))
        }
    }

    func test_suggestions_transportFailure_throws() async {
        let client = SpellClient(endpoint: endpoint, apiKey: "k", model: "m",
                                 transport: StubTransport(result: .failure(URLError(.notConnectedToInternet))))
        await XCTAssertThrowsErrorAsync(try await client.suggestions(for: "word")) { error in
            XCTAssertEqual(error as? SpellClientError, .transport)
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
