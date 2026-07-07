import XCTest
@testable import SpellerCore

final class ScaffoldTests: XCTestCase {
    func test_libraryVersion_isNonEmpty() {
        XCTAssertFalse(SpellerCore.libraryVersion.isEmpty)
    }
}
