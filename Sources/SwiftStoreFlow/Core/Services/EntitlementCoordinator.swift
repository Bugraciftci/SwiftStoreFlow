import Foundation

/// Actor-isolated domain coordinator managing purchase deduplication, verification, and offline fallback.
public actor EntitlementCoordinator {
    private let client: any StoreClientProtocol
    private let cache: any EntitlementCacheProtocol
    private let analytics: any PaywallAnalyticsProtocol
    private var isPurchaseActive = false

    public init(
        client: any StoreClientProtocol,
        cache: any EntitlementCacheProtocol = KeychainEntitlementCache(),
        analytics: any PaywallAnalyticsProtocol = NoOpPaywallAnalytics()
    ) {
        self.client = client
        self.cache = cache
        self.analytics = analytics
    }

    public func loadPlans(productIDs: [String]) async -> Result<[SubscriptionPlan], StoreFlowError> {
        do {
            let plans = try await client.fetchPlans(productIDs: productIDs)
            guard !plans.isEmpty else {
                return .failure(.productsUnavailable)
            }
            return .success(plans)
        } catch let error as StoreFlowError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    /// Refreshes entitlement from StoreKit and transparently falls back to cached Keychain state when offline.
    public func refreshEntitlement() async -> EntitlementState {
        do {
            let liveState = try await client.currentEntitlement()
            try? await cache.save(liveState)
            return liveState
        } catch {
            if let cached = await cache.load() {
                return cached
            }
            return .free
        }
    }

    /// Executes a single in-flight purchase guarded against double-tap re-entrancy.
    public func purchase(productID: String) async -> Result<PurchaseOutcome, StoreFlowError> {
        guard !isPurchaseActive else {
            return .failure(.purchaseInProgress)
        }

        isPurchaseActive = true
        defer { isPurchaseActive = false }

        await analytics.track(.purchaseStarted(productID: productID))

        do {
            let outcome = try await client.purchase(productID: productID)
            switch outcome {
            case .verified(let state):
                try? await cache.save(state)
                await analytics.track(.purchaseSucceeded(productID: productID, tier: state.tier))
            case .pending:
                await analytics.track(.purchasePending(productID: productID))
            case .userCancelled:
                await analytics.track(.purchaseCancelled(productID: productID))
            }
            return .success(outcome)
        } catch let error as StoreFlowError {
            await analytics.track(.purchaseFailed(productID: productID, reason: error.localizedDescription))
            return .failure(error)
        } catch {
            let wrapped = StoreFlowError.unknown(error.localizedDescription)
            await analytics.track(.purchaseFailed(productID: productID, reason: wrapped.localizedDescription))
            return .failure(wrapped)
        }
    }

    public func restorePurchases() async -> Result<EntitlementState, StoreFlowError> {
        await analytics.track(.restoreTriggered)
        do {
            let restored = try await client.restorePurchases()
            try? await cache.save(restored)
            await analytics.track(.restoreCompleted(isProActive: restored.isProActive))
            return .success(restored)
        } catch let error as StoreFlowError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
}
