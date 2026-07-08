import XCTest
@testable import SpellerCore

final class SettingsTests: XCTestCase {
    func test_defaults_areOpenRouterFree() {
        XCTAssertEqual(Defaults.endpoint, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertFalse(Defaults.model.isEmpty)
    }

    func test_inMemory_seedsWithDefaults() {
        let s = InMemorySettings()
        XCTAssertEqual(s.endpoint, Defaults.endpoint)
        XCTAssertEqual(s.model, Defaults.model)
    }

    func test_inMemory_roundTrips() {
        let s = InMemorySettings()
        s.model = "other/model:free"
        XCTAssertEqual(s.model, "other/model:free")
    }

    func test_inMemory_useContext_defaultsFalse() {
        XCTAssertFalse(InMemorySettings().useContext)   // opt-in (privacy)
    }

    func test_inMemory_useContext_roundTrips() {
        let s = InMemorySettings()
        s.useContext = true
        XCTAssertTrue(s.useContext)
    }
}
