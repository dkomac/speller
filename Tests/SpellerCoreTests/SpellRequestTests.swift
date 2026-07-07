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
}
