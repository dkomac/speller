import XCTest
@testable import SpellerCore

final class ClipboardServiceTests: XCTestCase {
    func test_snapshotAndClear_clearsButRemembers() {
        let pb = FakePasteboard(); pb.writeString("original")
        let svc = ClipboardService(pb)
        svc.snapshotAndClear()
        XCTAssertNil(pb.readString())
    }

    func test_currentString_readsLiveValue() {
        let pb = FakePasteboard()
        let svc = ClipboardService(pb)
        svc.snapshotAndClear()
        pb.writeString("recieve") // simulates the ⌘C result
        XCTAssertEqual(svc.currentString(), "recieve")
    }

    func test_restore_afterPaste_bringsBackOriginal() {
        let pb = FakePasteboard(); pb.writeString("original")
        let svc = ClipboardService(pb)
        svc.snapshotAndClear()
        svc.placeForPaste("receive")
        XCTAssertEqual(pb.readString(), "receive")
        svc.restore()
        XCTAssertEqual(pb.readString(), "original")
    }

    func test_restore_whenNoOriginal_clears() {
        let pb = FakePasteboard()
        let svc = ClipboardService(pb)
        svc.snapshotAndClear()      // nothing was there
        svc.placeForPaste("receive")
        svc.restore()
        XCTAssertNil(pb.readString())
    }
}
