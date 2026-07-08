import XCTest
@testable import SpellerCore

final class SpellRequestTests: XCTestCase {
    private func json(_ data: Data) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func test_body_setsModelAndMessages() {
        let obj = json(SpellRequest.body(model: "some/model:free", input: "recieve"))
        XCTAssertEqual(obj["model"] as? String, "some/model:free")
        let messages = obj["messages"] as! [[String: String]]
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[0]["content"], SpellRequest.systemPrompt)
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertEqual(messages[1]["content"], "recieve")
    }

    func test_systemPrompt_mentionsJSONArrayAndDescribeMode() {
        let p = SpellRequest.systemPrompt.lowercased()
        XCTAssertTrue(p.contains("json"))
        XCTAssertTrue(p.contains("array"))
        XCTAssertTrue(p.contains("describ"))
    }

    func test_body_withContext_includesContextAndWord() {
        let obj = json(SpellRequest.body(model: "m", input: "dej", context: "jag älskar dej"))
        let messages = obj["messages"] as! [[String: String]]
        let user = messages[1]["content"]!
        XCTAssertTrue(user.contains("dej"))
        XCTAssertTrue(user.contains("jag älskar dej"))
    }

    func test_body_nilContext_isJustInput() {
        let obj = json(SpellRequest.body(model: "m", input: "recieve", context: nil))
        let messages = obj["messages"] as! [[String: String]]
        XCTAssertEqual(messages[1]["content"], "recieve")
    }

    func test_body_blankContext_isJustInput() {
        let obj = json(SpellRequest.body(model: "m", input: "recieve", context: "   "))
        let messages = obj["messages"] as! [[String: String]]
        XCTAssertEqual(messages[1]["content"], "recieve")
    }

    func test_systemPrompt_mentionsLanguageDetection() {
        let p = SpellRequest.systemPrompt.lowercased()
        XCTAssertTrue(p.contains("language"))
        XCTAssertTrue(p.contains("detect"))
    }
}
