import XCTest
@testable import SpellerCore

final class SecretStoreTests: XCTestCase {
    func test_inMemory_defaultsEmpty() {
        XCTAssertEqual(InMemorySecretStore().apiKey, "")
    }

    func test_inMemory_roundTrips() {
        let s = InMemorySecretStore()
        s.apiKey = "sk-123"
        XCTAssertEqual(s.apiKey, "sk-123")
    }
}
