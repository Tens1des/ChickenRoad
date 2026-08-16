import XCTest
@testable import ChikenRoad

final class ConsentGateTests: XCTestCase {
    func testRetryDelayIsExactlyThreeDays() {
        XCTAssertEqual(ConsentGate.retryDelay, 3 * 24 * 60 * 60)

        let skippedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let firstEligibleDate = skippedAt.addingTimeInterval(ConsentGate.retryDelay)
        XCTAssertEqual(firstEligibleDate, Date(timeIntervalSince1970: 1_800_259_200))
    }
}
