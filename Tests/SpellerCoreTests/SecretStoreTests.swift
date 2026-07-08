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

    func test_file_defaultsEmptyThenRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speller-test-\(UUID().uuidString).key")
        defer { try? FileManager.default.removeItem(at: url) }

        let s = FileSecretStore(url: url)
        XCTAssertEqual(s.apiKey, "")          // no file yet → empty
        s.apiKey = "sk-file-456"
        XCTAssertEqual(s.apiKey, "sk-file-456")
        // A fresh instance reads the persisted value back.
        XCTAssertEqual(FileSecretStore(url: url).apiKey, "sk-file-456")
    }

    func test_file_trimsWhitespaceAndNewlines() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speller-test-\(UUID().uuidString).key")
        defer { try? FileManager.default.removeItem(at: url) }

        let s = FileSecretStore(url: url)
        s.apiKey = "  sk-trim-789\n"
        XCTAssertEqual(s.apiKey, "sk-trim-789")
    }
}
