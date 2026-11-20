import Foundation

/// Abstraction over StoreKit 2 allowing deterministic testing without App Store sandbox dependencies.
public protocol StoreClientProtocol: Sendable {
    func fetchPlans(productIDs: [String]) async throws -> [SubscriptionPlan]
    func purchase(productID: String) async throws -> PurchaseOutcome
    func currentEntitlement() async throws -> EntitlementState
    func restorePurchases() async throws -> EntitlementState
}

/// Secure persistence boundary for offline-first entitlement access.
public protocol EntitlementCacheProtocol: Sendable {
    func load() async -> EntitlementState?
    func save(_ state: EntitlementState) async throws
    func clear() async throws
}

/// Structured paywall funnel events for analytics pipelines (Firebase, TelemetryDeck, Amplitude, etc.).
public enum PaywallAnalyticsEvent: Equatable, Sendable {
    case paywallViewed(placement: String)
    case experimentExposed(experimentID: String, variantID: String, isHoldout: Bool)
    case planSelected(productID: String)
    case purchaseStarted(productID: String)
    case purchaseSucceeded(productID: String, tier: EntitlementTier)
    case purchaseCancelled(productID: String)
    case purchasePending(productID: String)
    case purchaseFailed(productID: String, reason: String)
    case restoreTriggered
    case restoreCompleted(isProActive: Bool)
}

/// Telemetry sink protocol injected into ViewModels and Coordinators.
public protocol PaywallAnalyticsProtocol: Sendable {
    func track(_ event: PaywallAnalyticsEvent) async
}

/// Default no-op analytics sink.
public struct NoOpPaywallAnalytics: PaywallAnalyticsProtocol {
    public init() {}
    public func track(_ event: PaywallAnalyticsEvent) async {}
}
