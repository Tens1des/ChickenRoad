import Foundation
import XCTest
@testable import ChikenRoad

final class PushInboxTests: XCTestCase {
    private let inbox = PushInbox.shared

    override func setUp() {
        super.setUp()
        _ = inbox.consume()
    }

    override func tearDown() {
        _ = inbox.consume()
        super.tearDown()
    }

    func testAbsoluteHTTPLinkIsStoredAndConsumedExactlyOnce() {
        let expected = URL(string: "https://web.example/path?campaign=one#offer")!

        XCTAssertTrue(inbox.accept(userInfo: ["url": expected.absoluteString]))
        XCTAssertEqual(inbox.consume(), expected)
        XCTAssertNil(inbox.consume())
    }

    func testNestedDataURLIsReadToo() {
        let expected = URL(string: "https://web.example/from-data")!

        XCTAssertTrue(inbox.accept(userInfo: ["data": ["url": expected.absoluteString]]))
        XCTAssertEqual(inbox.consume(), expected)
    }

    func testCustomSchemeRelativeAndHostlessLinksAreRejected() {
        XCTAssertFalse(inbox.accept(userInfo: ["url": "bankapp://offer/42"]))
        XCTAssertFalse(inbox.accept(userInfo: ["url": "/relative/path"]))
        XCTAssertFalse(inbox.accept(userInfo: ["url": "https:hostless-payload"]))
        XCTAssertNil(inbox.consume())
    }
}
