import XCTest
@testable import SwiftStoreFlow

private struct StubReceiptValidator: ReceiptValidatorProtocol {
    let decision: ValidationDecision
    let shouldThrow: Bool

    init(decision: ValidationDecision = .temporarilyUnavailable, shouldThrow: Bool = false) {
        self.decision = decision
        self.shouldThrow = shouldThrow
    }

    func validate(snapshot: SubscriptionReceiptSnapshot) async throws -> ValidationDecision {
        if shouldThrow {
            throw StoreFlowError.networkUnavailable
        }
        return decision
    }
}

private struct MockTransactionStreamProvider: TransactionStreamProviderProtocol {
    let snapshots: [SubscriptionReceiptSnapshot]

    func updates() -> AsyncStream<SubscriptionReceiptSnapshot> {
        AsyncStream { continuation in
            for item in snapshots {
                continuation.yield(item)
            }
            continuation.finish()
        }
    }
}

final class TransactionObserverTests: XCTestCase {
    func testValidReceiptSnapshotPersistsToCacheAndEmitsStreamEvent() async {
        let cache = InMemoryEntitlementCache()
        let validator = LocalStoreKitReceiptValidator(tierMapping: ["app.studio.yearly": .studio])
        let observer = TransactionObserverActor(validator: validator, cache: cache)

        let snapshot = SubscriptionReceiptSnapshot(
            originalTransactionID: "tx-9001",
            productID: "app.studio.yearly",
            environment: .production,
            expirationDate: Date().addingTimeInterval(3600 * 24 * 365),
            renewalState: .subscribed,
            signedJWSRepresentation: "eyJhbGciOiJFUzI1NiJ9.payload.sig"
        )

        let event = await observer.process(snapshot: snapshot)

        XCTAssertEqual(event.state.tier, .studio)
        XCTAssertEqual(event.renewalState, .subscribed)
        let cached = await cache.load()
        XCTAssertEqual(cached?.tier, .studio)
    }

    func testRevokedReceiptClearsCacheAndDemotesToFree() async {
        let cache = InMemoryEntitlementCache(initialState: MockStoreClient.proEntitlement)
        let validator = LocalStoreKitReceiptValidator()
        let observer = TransactionObserverActor(validator: validator, cache: cache)

        let revoked = SubscriptionReceiptSnapshot(
            originalTransactionID: "tx-9002",
            productID: "app.pro.yearly",
            renewalState: .revoked
        )

        let event = await observer.process(snapshot: revoked)

        XCTAssertEqual(event.state, .free)
        XCTAssertEqual(event.renewalState, .revoked)
        let cached = await cache.load()
        XCTAssertNil(cached)
    }

    func testOfflineGraceWindowRetainsFreshCachedEntitlement() async {
        let freshCache = InMemoryEntitlementCache(initialState: MockStoreClient.proEntitlement)
        let observer = TransactionObserverActor(
            validator: StubReceiptValidator(shouldThrow: true),
            cache: freshCache,
            offlinePolicy: .allowCachedGraceWindow(seconds: 3600)
        )

        let snapshot = SubscriptionReceiptSnapshot(
            originalTransactionID: "tx-9003",
            productID: "app.pro.yearly",
            renewalState: .inGracePeriod
        )

        let event = await observer.process(snapshot: snapshot)

        XCTAssertTrue(event.state.isProActive)
        XCTAssertEqual(event.renewalState, .inGracePeriod)
        XCTAssertTrue(event.renewalState.requiresBillingAttention)
    }

    func testStrictOnlinePolicyDeniesAccessWhenValidatorUnavailable() async {
        let freshCache = InMemoryEntitlementCache(initialState: MockStoreClient.proEntitlement)
        let observer = TransactionObserverActor(
            validator: StubReceiptValidator(decision: .temporarilyUnavailable),
            cache: freshCache,
            offlinePolicy: .strictOnline
        )

        let snapshot = SubscriptionReceiptSnapshot(
            originalTransactionID: "tx-9004",
            productID: "app.pro.yearly",
            renewalState: .subscribed
        )

        let event = await observer.process(snapshot: snapshot)
        XCTAssertEqual(event.state, .free)
    }

    func testStartObservingProcessesTransactionStreamSnapshots() async {
        let cache = InMemoryEntitlementCache()
        let observer = TransactionObserverActor(validator: LocalStoreKitReceiptValidator(), cache: cache)
        let provider = MockTransactionStreamProvider(snapshots: [
            SubscriptionReceiptSnapshot(
                originalTransactionID: "tx-stream-1",
                productID: "app.pro.yearly",
                expirationDate: Date().addingTimeInterval(86_400),
                renewalState: .subscribed
            )
        ])

        await observer.startObserving(provider: provider)
        try? await Task.sleep(nanoseconds: 60_000_000)
        await observer.stopObserving()

        let latest = await observer.currentLatestEvent()
        XCTAssertEqual(latest?.source, .transactionStream)
        XCTAssertEqual(latest?.state.tier, .pro)
    }

    func testRevenueMetricsSnapshotCalculations() {
        let metrics = RevenueMetricsSnapshot(
            paywallViews: 200,
            purchaseAttempts: 40,
            verifiedPurchases: 20,
            cancelledPurchases: 18,
            failedPurchases: 2
        )

        XCTAssertEqual(metrics.conversionRate, 0.10, accuracy: 0.0001)
        XCTAssertEqual(metrics.checkoutCompletionRate, 0.50, accuracy: 0.0001)
    }

    func testPromotionalOfferMetadataAndBillingRetrySemantics() {
        let offer = PromotionalOfferMetadata(
            offerID: "winback_50",
            kind: .winBack,
            discountedDisplayPrice: "$29.99",
            durationDays: 365,
            isEligible: true
        )
        let plan = SubscriptionPlan(
            id: "app.pro.yearly",
            title: "Pro Yearly",
            subtitle: "Win-back special",
            displayPrice: "$59.99",
            priceDecimal: 59.99,
            billingPeriod: .yearly,
            promotionalOffer: offer
        )

        XCTAssertEqual(plan.promotionalOffer?.kind, .winBack)
        XCTAssertTrue(RenewalState.inGracePeriod.grantsPremiumAccess)
        XCTAssertTrue(RenewalState.inBillingRetry.requiresBillingAttention)
        XCTAssertFalse(RenewalState.inBillingRetry.grantsPremiumAccess)
    }
}
