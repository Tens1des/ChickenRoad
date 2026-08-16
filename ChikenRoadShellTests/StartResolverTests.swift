import XCTest
@testable import ChikenRoad

/// Вся таблица режимов запуска: восемь строк, восемь тестов, ни одного похода в
/// сеть — политика на то и чистая функция.
final class StartResolverTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testUndecidedOnlineAsksForFirstDecision() {
        XCTAssertEqual(
            StartResolver.resolve(mode: .undecided, grant: nil, reachability: .online, now: now),
            .exchange(reason: .firstDecision, fallback: nil)
        )
    }

    func testUndecidedOfflineShowsOfflineWithoutDecidingAnything() {
        XCTAssertEqual(
            StartResolver.resolve(mode: .undecided, grant: nil, reachability: .offline, now: now),
            .reportOffline
        )
    }

    func testUndecidedWhileReachabilityIsCheckingWaits() {
        XCTAssertEqual(
            StartResolver.resolve(mode: .undecided, grant: nil, reachability: .checking, now: now),
            .awaitReachability
        )
    }

    func testNativeLockBeatsReachabilityAndForcedRefresh() {
        let grant = LinkGrant(
            rawLink: "https://cached.example/path",
            expiresEpoch: now.timeIntervalSince1970 + 300
        )

        for reachability in [ReachabilityProbe.State.checking, .offline, .online] {
            XCTAssertEqual(
                StartResolver.resolve(
                    mode: .native,
                    grant: grant,
                    reachability: reachability,
                    now: now,
                    forceRefresh: true
                ),
                .handOverToGame
            )
        }
    }

    func testWebOpensLiveGrantWithoutAsking() {
        let grant = LinkGrant(
            rawLink: "https://cached.example/valid",
            expiresEpoch: now.timeIntervalSince1970 + 1
        )

        XCTAssertEqual(
            StartResolver.resolve(mode: .web, grant: grant, reachability: .online, now: now),
            .openGrant(grant)
        )
    }

    func testWebRefreshesGrantExpiredExactlyNowAndKeepsItAsFallback() {
        let grant = LinkGrant(
            rawLink: "https://cached.example/expired",
            expiresEpoch: now.timeIntervalSince1970
        )

        XCTAssertEqual(
            StartResolver.resolve(mode: .web, grant: grant, reachability: .online, now: now),
            .exchange(reason: .grantExpired, fallback: grant)
        )
    }

    func testWebWithoutGrantAsksWithoutFallback() {
        XCTAssertEqual(
            StartResolver.resolve(mode: .web, grant: nil, reachability: .online, now: now),
            .exchange(reason: .grantMissing, fallback: nil)
        )
    }

    func testForcedRefreshKeepsLiveGrantAsFallback() {
        let grant = LinkGrant(
            rawLink: "https://cached.example/token-refresh",
            expiresEpoch: now.timeIntervalSince1970 + 3_600
        )

        XCTAssertEqual(
            StartResolver.resolve(
                mode: .web,
                grant: grant,
                reachability: .online,
                now: now,
                forceRefresh: true
            ),
            .exchange(reason: .pushTokenRotated, fallback: grant)
        )
    }
}
