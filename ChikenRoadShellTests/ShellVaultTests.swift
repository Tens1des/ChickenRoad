import XCTest
@testable import ChikenRoad

final class ShellVaultTests: XCTestCase {
    private var suiteName: String!
    private var store: UserDefaults!
    private var sut: ShellVault!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "ChikenRoadShellTests.\(UUID().uuidString)"
        store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store.removePersistentDomain(forName: suiteName)
        sut = ShellVault(store: store)
    }

    override func tearDownWithError() throws {
        store.removePersistentDomain(forName: suiteName)
        sut = nil
        store = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testFreshVaultIsUndecidedAndPermitsExchange() {
        XCTAssertEqual(sut.installMode, .undecided)
        XCTAssertNil(sut.storedGrant)
        XCTAssertTrue(sut.permitsExchange)
    }

    func testSealWebStoresModeAndCompleteGrantAndSurvivesRestart() {
        let grant = LinkGrant(
            rawLink: "https://example.test/session?value=raw%2Fvalue",
            expiresEpoch: 1_900_000_000.25
        )

        sut.sealWeb(grant)

        XCTAssertEqual(sut.installMode, .web)
        XCTAssertEqual(sut.storedGrant, grant)
        XCTAssertTrue(sut.permitsExchange)

        let reopened = ShellVault(store: store)
        XCTAssertEqual(reopened.installMode, .web)
        XCTAssertEqual(reopened.storedGrant, grant)
    }

    func testHalfWrittenGrantIsNeverExposed() {
        store.set("https://example.test/incomplete", forKey: "henpath.shell.link_url")
        XCTAssertNil(sut.storedGrant)

        store.removeObject(forKey: "henpath.shell.link_url")
        store.set(1_900_000_000, forKey: "henpath.shell.link_expires")
        XCTAssertNil(sut.storedGrant)
    }

    func testSealNativeDropsGrantAndForbidsExchangeForever() {
        sut.sealWeb(
            LinkGrant(
                rawLink: "https://example.test/previous-web",
                expiresEpoch: 1_900_000_000
            )
        )

        sut.sealNative()

        XCTAssertEqual(sut.installMode, .native)
        XCTAssertNil(sut.storedGrant)
        XCTAssertFalse(sut.permitsExchange)

        let reopened = ShellVault(store: store)
        XCTAssertEqual(reopened.installMode, .native)
        XCTAssertNil(reopened.storedGrant)
        XCTAssertFalse(reopened.permitsExchange)
    }

    func testUnknownStoredModeFallsBackToUndecided() {
        store.set("unexpected-mode", forKey: "henpath.shell.mode")
        XCTAssertEqual(sut.installMode, .undecided)
    }

    func testConsentSkipDateRoundTripsAndCanBeCleared() {
        let date = Date(timeIntervalSince1970: 1_801_234_567.5)

        sut.consentSkippedAt = date
        XCTAssertEqual(sut.consentSkippedAt, date)

        sut.consentSkippedAt = nil
        XCTAssertNil(sut.consentSkippedAt)
    }

    func testDeliveredPushTokenRoundTripsAndCanBeCleared() {
        sut.deliveredPushToken = "fcm-token-123"
        XCTAssertEqual(sut.deliveredPushToken, "fcm-token-123")

        sut.deliveredPushToken = nil
        XCTAssertNil(sut.deliveredPushToken)
    }
}
