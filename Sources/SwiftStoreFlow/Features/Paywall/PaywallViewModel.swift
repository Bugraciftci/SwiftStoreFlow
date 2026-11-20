import Combine
import Foundation

/// Main-actor MVVM ViewModel driving SwiftUI paywall rendering, A/B experimentation, and live entitlement updates.
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
    @Published public private(set) var renewalState: RenewalState = .expired
    @Published public private(set) var activeExperimentAssignment: ExperimentAssignment?
    @Published public private(set) var templateStyle: PaywallTemplateStyle = .standardCards
    @Published public private(set) var headline: String = "Unlock Pro Access"
    @Published public private(set) var ctaTitle: String = "Continue"

    private let coordinator: EntitlementCoordinator
    private let analytics: any PaywallAnalyticsProtocol
    private let transactionObserver: TransactionObserverActor?
    private let bucketer: ExperimentBucketer
    private let experiment: PaywallExperiment?
    private let userID: String
    private let productIDs: [String]
    private let placement: String
    private var streamTask: Task<Void, Never>?

    public init(
        coordinator: EntitlementCoordinator,
        productIDs: [String],
        placement: String = "default_paywall",
        analytics: any PaywallAnalyticsProtocol = NoOpPaywallAnalytics(),
        transactionObserver: TransactionObserverActor? = nil,
        experiment: PaywallExperiment? = nil,
        bucketer: ExperimentBucketer = ExperimentBucketer(),
        userID: String = "anonymous"
    ) {
        self.coordinator = coordinator
        self.productIDs = productIDs
        self.placement = placement
        self.analytics = analytics
        self.transactionObserver = transactionObserver
        self.experiment = experiment
        self.bucketer = bucketer
        self.userID = userID
    }

    deinit {
        streamTask?.cancel()
    }

    public var selectedPlan: SubscriptionPlan? {
        plans.first { $0.id == selectedPlanID }
    }

    public var isBusy: Bool {
        phase == .loading || phase == .purchasing || phase == .restoring
    }

    public var showsBillingWarningBanner: Bool {
        renewalState.requiresBillingAttention
    }

    public func onAppear() async {
        phase = .loading
        await applyExperimentIfConfigured()
        await analytics.track(.paywallViewed(placement: placement))
        startListeningToTransactionStreamIfNeeded()

        async let fetchedEntitlement = coordinator.refreshEntitlement()
        async let plansResult = coordinator.loadPlans(productIDs: productIDs)

        entitlement = await fetchedEntitlement
        if entitlement.isProActive {
            renewalState = entitlement.isInGracePeriod ? .inGracePeriod : .subscribed
        }

        switch await plansResult {
        case .success(let loadedPlans):
            plans = loadedPlans
            if selectedPlanID == nil {
                let preferredPeriod = activeExperimentAssignment?.variant.defaultBillingPeriod ?? .yearly
                selectedPlanID = loadedPlans.first(where: { $0.billingPeriod == preferredPeriod })?.id
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
                renewalState = newState.isInGracePeriod ? .inGracePeriod : .subscribed
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
            renewalState = restoredState.isProActive ? .subscribed : .expired
            phase = restoredState.isProActive ? .purchased : .ready
        case .failure(let error):
            phase = .failed(error.localizedDescription)
        }
    }

    private func applyExperimentIfConfigured() async {
        guard let experiment,
              let assignment = bucketer.assign(userID: userID, experiment: experiment) else {
            return
        }
        activeExperimentAssignment = assignment
        templateStyle = assignment.variant.templateStyle
        headline = assignment.variant.headline
        ctaTitle = assignment.variant.ctaTitle
        await analytics.track(
            .experimentExposed(
                experimentID: assignment.experimentID,
                variantID: assignment.variant.id,
                isHoldout: assignment.isHoldout
            )
        )
    }

    private func startListeningToTransactionStreamIfNeeded() {
        guard let transactionObserver, streamTask == nil else { return }
        streamTask = Task { [weak self] in
            let stream = await transactionObserver.entitlementStream()
            for await event in stream {
                guard let self, !Task.isCancelled else { break }
                self.entitlement = event.state
                self.renewalState = event.renewalState
                if event.state.isProActive {
                    self.phase = .purchased
                } else if self.phase == .purchased {
                    self.phase = .ready
                }
            }
        }
    }
}
