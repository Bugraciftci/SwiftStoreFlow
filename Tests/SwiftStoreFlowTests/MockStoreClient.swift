import Foundation
@testable import SwiftStoreFlow

actor MockStoreClient: StoreClientProtocol {
    var plansResult: Result<[SubscriptionPlan], any Error>
    var purchaseResult: Result<PurchaseOutcome, any Error>
    var entitlementResult: Result<EntitlementState, any Error>
    var restoreResult: Result<EntitlementState, any Error>
    var purchaseDelayNanoseconds: UInt64 = 0

    init(
        plansResult: Result<[SubscriptionPlan], any Error> = .success(MockStoreClient.samplePlans),
        purchaseResult: Result<PurchaseOutcome, any Error> = .success(.verified(MockStoreClient.proEntitlement)),
        entitlementResult: Result<EntitlementState, any Error> = .success(.free),
        restoreResult: Result<EntitlementState, any Error> = .success(MockStoreClient.proEntitlement)
    ) {
        self.plansResult = plansResult
        self.purchaseResult = purchaseResult
        self.entitlementResult = entitlementResult
        self.restoreResult = restoreResult
    }

    func setPurchaseDelay(_ nanoseconds: UInt64) {
        purchaseDelayNanoseconds = nanoseconds
    }

    func setPurchaseResult(_ result: Result<PurchaseOutcome, any Error>) {
        purchaseResult = result
    }

    func setEntitlementResult(_ result: Result<EntitlementState, any Error>) {
        entitlementResult = result
    }

    func fetchPlans(productIDs: [String]) async throws -> [SubscriptionPlan] {
        try plansResult.get()
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        if purchaseDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: purchaseDelayNanoseconds)
        }
        return try purchaseResult.get()
    }

    func currentEntitlement() async throws -> EntitlementState {
        try entitlementResult.get()
    }

    func restorePurchases() async throws -> EntitlementState {
        try restoreResult.get()
    }

    static let samplePlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "app.pro.monthly",
            title: "Pro Monthly",
            subtitle: "Flexible monthly access",
            displayPrice: "$9.99",
            priceDecimal: Decimal(string: "9.99")!,
            billingPeriod: .monthly
        ),
        SubscriptionPlan(
            id: "app.pro.yearly",
            title: "Pro Yearly",
            subtitle: "Best value for power users",
            displayPrice: "$59.99",
            priceDecimal: Decimal(string: "59.99")!,
            billingPeriod: .yearly,
            trialDescription: "7-day free trial"
        )
    ]

    static let proEntitlement = EntitlementState(
        tier: .pro,
        activeProductIDs: ["app.pro.yearly"],
        expirationDate: Date().addingTimeInterval(3600 * 24 * 365),
        isInGracePeriod: false
    )
}

actor RecordingAnalytics: PaywallAnalyticsProtocol {
    private(set) var events: [PaywallAnalyticsEvent] = []

    func track(_ event: PaywallAnalyticsEvent) async {
        events.append(event)
    }

    func allEvents() -> [PaywallAnalyticsEvent] {
        events
    }
}
