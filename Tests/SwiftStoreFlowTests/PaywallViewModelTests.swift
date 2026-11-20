import XCTest
@testable import SwiftStoreFlow

@MainActor
final class PaywallViewModelTests: XCTestCase {
    func testOnAppearLoadsPlansAndPreselectsYearlyPlan() async {
        let client = MockStoreClient()
        let analytics = RecordingAnalytics()
        let coordinator = EntitlementCoordinator(
            client: client,
            cache: InMemoryEntitlementCache(),
            analytics: analytics
        )
        let viewModel = PaywallViewModel(
            coordinator: coordinator,
            productIDs: ["app.pro.monthly", "app.pro.yearly"],
            placement: "onboarding",
            analytics: analytics
        )

        await viewModel.onAppear()

        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertEqual(viewModel.plans.count, 2)
        XCTAssertEqual(viewModel.selectedPlanID, "app.pro.yearly")

        let events = await analytics.allEvents()
        XCTAssertEqual(events.first, .paywallViewed(placement: "onboarding"))
    }

    func testPurchaseSelectedPlanTransitionsToPurchased() async {
        let client = MockStoreClient()
        let coordinator = EntitlementCoordinator(client: client, cache: InMemoryEntitlementCache())
        let viewModel = PaywallViewModel(
            coordinator: coordinator,
            productIDs: ["app.pro.monthly", "app.pro.yearly"]
        )

        await viewModel.onAppear()
        await viewModel.selectPlan("app.pro.monthly")
        await viewModel.purchaseSelectedPlan()

        XCTAssertEqual(viewModel.phase, .purchased)
        XCTAssertTrue(viewModel.entitlement.isProActive)
    }

    func testRestorePurchasesUnlocksProAccess() async {
        let client = MockStoreClient()
        let coordinator = EntitlementCoordinator(client: client, cache: InMemoryEntitlementCache())
        let viewModel = PaywallViewModel(
            coordinator: coordinator,
            productIDs: ["app.pro.monthly", "app.pro.yearly"]
        )

        await viewModel.onAppear()
        await viewModel.restorePurchases()

        XCTAssertEqual(viewModel.phase, .purchased)
        XCTAssertTrue(viewModel.entitlement.isProActive)
    }

    func testProductsFailureTransitionsToFailedState() async {
        let client = MockStoreClient(plansResult: .failure(StoreFlowError.productsUnavailable))
        let coordinator = EntitlementCoordinator(client: client, cache: InMemoryEntitlementCache())
        let viewModel = PaywallViewModel(
            coordinator: coordinator,
            productIDs: ["missing.id"]
        )

        await viewModel.onAppear()

        if case .failed(let message) = viewModel.phase {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected failed phase, got \(viewModel.phase)")
        }
    }
}
