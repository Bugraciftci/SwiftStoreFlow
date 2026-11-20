import Combine
import Foundation

/// Main-actor MVVM ViewModel driving SwiftUI paywall rendering and entitlement state transitions.
@MainActor
public final class PaywallViewModel: ObservableObject {
    public enum Phase: Equatable, Sendable {
        case idle
        case loading
        case ready
        case purchasing
        case restoring
        case pendingApproval
        case purchased
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var plans: [SubscriptionPlan] = []
    @Published public var selectedPlanID: String?
    @Published public private(set) var entitlement: EntitlementState = .free

    private let coordinator: EntitlementCoordinator
    private let analytics: any PaywallAnalyticsProtocol
    private let productIDs: [String]
    private let placement: String

    public init(
        coordinator: EntitlementCoordinator,
        productIDs: [String],
        placement: String = "default_paywall",
        analytics: any PaywallAnalyticsProtocol = NoOpPaywallAnalytics()
    ) {
        self.coordinator = coordinator
        self.productIDs = productIDs
        self.placement = placement
        self.analytics = analytics
    }

    public var selectedPlan: SubscriptionPlan? {
        plans.first { $0.id == selectedPlanID }
    }

    public var isBusy: Bool {
        phase == .loading || phase == .purchasing || phase == .restoring
    }

    public func onAppear() async {
        phase = .loading
        await analytics.track(.paywallViewed(placement: placement))

        async let fetchedEntitlement = coordinator.refreshEntitlement()
        async let plansResult = coordinator.loadPlans(productIDs: productIDs)

        entitlement = await fetchedEntitlement

        switch await plansResult {
        case .success(let loadedPlans):
            plans = loadedPlans
            if selectedPlanID == nil {
                selectedPlanID = loadedPlans.first(where: { $0.billingPeriod == .yearly })?.id
                    ?? loadedPlans.first?.id
            }
            phase = entitlement.isProActive ? .purchased : .ready
        case .failure(let error):
            phase = .failed(error.localizedDescription)
        }
    }

    public func selectPlan(_ planID: String) async {
        guard plans.contains(where: { $0.id == planID }) else { return }
        selectedPlanID = planID
        await analytics.track(.planSelected(productID: planID))
    }

    public func purchaseSelectedPlan() async {
        guard let productID = selectedPlanID else { return }
        phase = .purchasing

        switch await coordinator.purchase(productID: productID) {
        case .success(let outcome):
            switch outcome {
            case .verified(let newState):
                entitlement = newState
                phase = .purchased
            case .pending:
                phase = .pendingApproval
            case .userCancelled:
                phase = .ready
            }
        case .failure(let error):
            phase = .failed(error.localizedDescription)
        }
    }

    public func restorePurchases() async {
        phase = .restoring

        switch await coordinator.restorePurchases() {
        case .success(let restoredState):
            entitlement = restoredState
            phase = restoredState.isProActive ? .purchased : .ready
        case .failure(let error):
            phase = .failed(error.localizedDescription)
        }
    }
}
