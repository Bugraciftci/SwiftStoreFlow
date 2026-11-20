import Foundation

/// Strongly-typed domain errors emitted across the purchase and verification pipeline.
public enum StoreFlowError: Error, Equatable, Sendable, LocalizedError {
    case productsUnavailable
    case purchaseInProgress
    case verificationFailed(String)
    case networkUnavailable
    case persistenceFailure(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            return "Subscription plans are currently unavailable. Please try again shortly."
        case .purchaseInProgress:
            return "Another purchase is already being processed."
        case .verificationFailed(let reason):
            return "Purchase verification failed: \(reason)"
        case .networkUnavailable:
            return "Unable to reach the App Store. Check your internet connection."
        case .persistenceFailure(let reason):
            return "Could not persist entitlement state: \(reason)"
        case .unknown(let message):
            return message
        }
    }
}
