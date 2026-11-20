import XCTest
@testable import SwiftStoreFlow

final class EntitlementCoordinatorTests: XCTestCase {
    func testPurchasePersistsEntitlementAndTracksAnalytics() async {
        let client = MockStoreClient()
        let cache = InMemoryEntitlementCache()
        let analytics = RecordingAnalytics()
        let coordinator = EntitlementCoordinator(client: client, cache: cache, analytics: analytics)

        let result = await coordinator.purchase(productID: "app.pro.yearly")

        switch result {
        case .success(.verified(let state)):
            XCTAssertTrue(state.isProActive)
            XCTAssertEqual(state.tier, .pro)
        default:
            XCTFail("Expected verified purchase outcome, got \(result)")
        }

        let cached = await cache.load()
        XCTAssertEqual(cached?.tier, .pro)

        let events = await analytics.allEvents()
        XCTAssertEqual(events, [
            .purchaseStarted(productID: "app.pro.yearly"),
            .purchaseSucceeded(productID: "app.pro.yearly", tier: .pro)
        ])
    }

    func testOfflineRefreshFallsBackToCachedEntitlement() async {
        let client = MockStoreClient(entitlementResult: .failure(StoreFlowError.networkUnavailable))
        let cache = InMemoryEntitlementCache(initialState: MockStoreClient.proEntitlement)
        let coordinator = EntitlementCoordinator(client: client, cache: cache)

        let refreshed = await coordinator.refreshEntitlement()

        XCTAssertTrue(refreshed.isProActive)
        XCTAssertEqual(refreshed.activeProductIDs, ["app.pro.yearly"])
    }

    func testConcurrentPurchaseAttemptsAreDeduplicated() async {
        let client = MockStoreClient()
        await client.setPurchaseDelay(150_000_000) // 150ms
        let coordinator = EntitlementCoordinator(client: client, cache: InMemoryEntitlementCache())

        async let first = coordinator.purchase(productID: "app.pro.yearly")
        try? await Task.sleep(nanoseconds: 25_000_000)
        async let second = coordinator.purchase(productID: "app.pro.yearly")

        let (r1, r2) = await (first, second)

        if case .success(.verified) = r1 {
            // Expected
        } else {
            XCTFail("First purchase should succeed, got \(r1)")
        }

        XCTAssertEqual(r2, .failure(.purchaseInProgress))
    }

    func testUserCancelledPurchaseDoesNotOverwriteCache() async {
        let client = MockStoreClient(purchaseResult: .success(.userCancelled))
        let cache = InMemoryEntitlementCache()
        let analytics = RecordingAnalytics()
        let coordinator = EntitlementCoordinator(client: client, cache: cache, analytics: analytics)

        let outcome = await coordinator.purchase(productID: "app.pro.monthly")

        XCTAssertEqual(outcome, .success(.userCancelled))
        let cached = await cache.load()
        XCTAssertNil(cached)
        let events = await analytics.allEvents()
        XCTAssertEqual(events.last, .purchaseCancelled(productID: "app.pro.monthly"))
    }

    func testAnnualSavingsCalculationAndExpirationAccess() {
        let yearly = MockStoreClient.samplePlans[1]
        let monthly = MockStoreClient.samplePlans[0]

        XCTAssertEqual(yearly.savingsPercentage(comparedToMonthly: monthly.priceDecimal), 50)

        let expired = EntitlementState(
            tier: .pro,
            activeProductIDs: ["app.pro.monthly"],
            expirationDate: Date().addingTimeInterval(-60),
            isInGracePeriod: false
        )
        XCTAssertFalse(expired.hasAccess(to: .pro))

        let grace = EntitlementState(
            tier: .pro,
            activeProductIDs: ["app.pro.monthly"],
            expirationDate: Date().addingTimeInterval(-60),
            isInGracePeriod: true
        )
        XCTAssertTrue(grace.hasAccess(to: .pro))
    }
}
