import XCTest
@testable import ChikenRoad

final class ExchangeEnvelopeTests: XCTestCase {
    private let sut = ExchangeEnvelope()

    func testContractKeysOverrideCollidingAttributionFields() throws {
        let body = try sut.seal(
            attribution: [
                "campaign": "summer",
                "media_source": "test-network",
                "af_id": "wrong-af-id",
                "bundle_id": "wrong.bundle",
                "os": "Android",
                "store_id": "id1",
                "locale": "wrong-locale"
            ],
            appsFlyerUID: "  af-uid-123  ",
            bundleIdentifier: "  com.company.product  ",
            storeID: "  1234567890  ",
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(body["campaign"] as? String, "summer")
        XCTAssertEqual(body["media_source"] as? String, "test-network")
        XCTAssertEqual(body["af_id"] as? String, "af-uid-123")
        XCTAssertEqual(body["bundle_id"] as? String, "com.company.product")
        XCTAssertEqual(body["os"] as? String, "iOS")
        XCTAssertEqual(body["store_id"] as? String, "id1234567890")
        XCTAssertEqual(body["locale"] as? String, "en-US")
    }

    func testArbitraryUDLFieldsAndExplicitNullSurvive() throws {
        let body = try sut.seal(
            attribution: [
                "deep_link_value": "offer-42",
                "custom_sub1": ["nested": true, "items": [1, 2, 3]],
                "custom_nullable": NSNull()
            ],
            appsFlyerUID: "af-id",
            bundleIdentifier: "com.company.product",
            storeID: "id1234567890"
        )

        XCTAssertEqual(body["deep_link_value"] as? String, "offer-42")
        let nested = try XCTUnwrap(body["custom_sub1"] as? [String: Any])
        XCTAssertEqual(nested["nested"] as? Bool, true)
        XCTAssertEqual(nested["items"] as? [Int], [1, 2, 3])
        XCTAssertTrue(body["custom_nullable"] is NSNull)
    }

    func testBlankOptionalFieldsAreRemovedEvenWhenAttributionCarriedStaleOnes() throws {
        let body = try sut.seal(
            attribution: [
                "push_token": "stale-token",
                "firebase_project_id": "stale-project"
            ],
            appsFlyerUID: "af-id",
            bundleIdentifier: "com.company.product",
            storeID: "id1234567890",
            pushToken: "   ",
            firebaseProjectID: nil
        )

        XCTAssertNil(body["push_token"])
        XCTAssertNil(body["firebase_project_id"])
    }

    func testLocaleIsRFC3066AndOptionalFieldsAreTrimmed() throws {
        let body = try sut.seal(
            attribution: [:],
            appsFlyerUID: "af-id",
            bundleIdentifier: "com.company.product",
            storeID: "id1234567890",
            locale: Locale(identifier: "pt_BR@calendar=gregorian"),
            pushToken: " token-123 ",
            firebaseProjectID: " project-123 "
        )

        XCTAssertEqual(body["locale"] as? String, "pt-BR")
        XCTAssertEqual(body["push_token"] as? String, "token-123")
        XCTAssertEqual(body["firebase_project_id"] as? String, "project-123")
    }

    func testAttributionThatCannotBecomeJSONIsRejectedWhole() {
        XCTAssertThrowsError(
            try sut.seal(
                attribution: ["unsupported": Date()],
                appsFlyerUID: "af-id",
                bundleIdentifier: "com.company.product",
                storeID: "id1234567890"
            )
        ) { error in
            XCTAssertEqual(error as? EnvelopeError, .valueNotRepresentableInJSON)
        }
    }
}
