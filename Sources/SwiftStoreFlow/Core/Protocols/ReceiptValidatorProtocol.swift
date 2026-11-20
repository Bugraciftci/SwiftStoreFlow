import Foundation

/// Policy governing how the coordinator responds when a remote receipt validator is unreachable.
public enum OfflineValidationPolicy: Equatable, Sendable {
    /// Rejects entitlement upgrades unless server-side JWS validation succeeds online.
    case strictOnline
    /// Permits locally verified StoreKit 2 entitlements if cached within the allowed grace window.
    case allowCachedGraceWindow(seconds: TimeInterval)
}

/// Decision returned by a server-side or cryptographic JWS receipt validator.
public enum ValidationDecision: Equatable, Sendable {
    case valid(EntitlementState)
    case rejected(reason: String)
    case temporarilyUnavailable
}

/// Protocol abstracting remote JWS / App Store Server API receipt verification.
public protocol ReceiptValidatorProtocol: Sendable {
    func validate(snapshot: SubscriptionReceiptSnapshot) async throws -> ValidationDecision
}

/// Default local passthrough validator trusting Apple's on-device StoreKit 2 cryptographic verification.
public struct LocalStoreKitReceiptValidator: ReceiptValidatorProtocol {
    private let tierMapping: [String: EntitlementTier]

    public init(tierMapping: [String: EntitlementTier] = [:]) {
        self.tierMapping = tierMapping
    }

    public func validate(snapshot: SubscriptionReceiptSnapshot) async throws -> ValidationDecision {
        guard snapshot.renewalState.grantsPremiumAccess else {
            return .rejected(reason: "Subscription state '\(snapshot.renewalState.rawValue)' does not grant access.")
        }

        let tier = tierMapping[snapshot.productID] ?? .pro
        let state = EntitlementState(
            tier: tier,
            activeProductIDs: [snapshot.productID],
            expirationDate: snapshot.expirationDate,
            isInGracePeriod: snapshot.renewalState == .inGracePeriod,
            lastVerifiedAt: Date()
        )
        return .valid(state)
    }
}
