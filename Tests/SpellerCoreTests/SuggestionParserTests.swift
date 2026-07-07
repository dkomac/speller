import XCTest
@testable import SpellerCore

final class SuggestionParserTests: XCTestCase {
    func test_parseContent_plainJSONArray() {
        XCTAssertEqual(SuggestionParser.parseContent(#"["philosophy"]"#), ["philosophy"])
    }

    func test_parseContent_multipleRanked() {
        XCTAssertEqual(
            SuggestionParser.parseContent(#"["practice", "practise"]"#),
            ["practice", "practise"]
        )
    }

    func test_parseContent_stripsCodeFencesAndProse() {
        let content = "Sure!\n```json\n[\"receive\", \"receipt\"]\n```"
        XCTAssertEqual(SuggestionParser.parseContent(content), ["receive", "receipt"])
    }

    func test_parseContent_trimsWhitespaceAndCaps5() {
        let content = #"[" a ","b","c","d","e","f"]"#
        XCTAssertEqual(SuggestionParser.parseContent(content), ["a", "b", "c", "d", "e"])
    }

    func test_parseContent_malformed_returnsEmpty() {
        XCTAssertEqual(SuggestionParser.parseContent("no array here"), [])
    }

    func test_parseResponseBody_extractsContent() {
        let body = #"{"choices":[{"message":{"content":"[\"insomnia\"]"}}]}"#
        XCTAssertEqual(SuggestionParser.parseResponseBody(Data(body.utf8)), ["insomnia"])
    }

    func test_parseResponseBody_missingChoices_returnsEmpty() {
        XCTAssertEqual(SuggestionParser.parseResponseBody(Data("{}".utf8)), [])
    }
}
