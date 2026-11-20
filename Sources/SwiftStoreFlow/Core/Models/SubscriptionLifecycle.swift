import Foundation

/// StoreKit execution environment extracted from verified App Store transactions.
public enum StoreEnvironment: String, Codable, Sendable, Equatable, Hashable {
    case production
    case sandbox
    case xcode
}

/// Canonical lifecycle state of an auto-renewable subscription.
public enum RenewalState: String, Codable, Sendable, Equatable, Hashable {
    case subscribed
    case inBillingRetry
    case inGracePeriod
    case expired
    case revoked

    /// Indicates whether the user should currently retain active premium access.
    public var grantsPremiumAccess: Bool {
        switch self {
        case .subscribed, .inGracePeriod:
            return true
        case .inBillingRetry, .expired, .revoked:
            return false
        }
    }

    /// Indicates whether the UI should surface a non-blocking billing resolution banner.
    public var requiresBillingAttention: Bool {
        self == .inBillingRetry || self == .inGracePeriod
    }
}

/// Promotional or introductory pricing metadata attached to a subscription plan.
public struct PromotionalOfferMetadata: Equatable, Hashable, Codable, Sendable {
    public enum OfferKind: String, Codable, Sendable, Hashable {
        case introductoryTrial
        case payAsYouGo
        case payUpFront
        case winBack
    }

    public let offerID: String
    public let kind: OfferKind
    public let discountedDisplayPrice: String
    public let durationDays: Int
    public let isEligible: Bool

    public init(
        offerID: String,
        kind: OfferKind,
        discountedDisplayPrice: String,
        durationDays: Int,
        isEligible: Bool = true
    ) {
        self.offerID = offerID
        self.kind = kind
        self.discountedDisplayPrice = discountedDisplayPrice
        self.durationDays = durationDays
        self.isEligible = isEligible
    }
}

/// Structured transaction snapshot passed into server-side JWS validation pipelines.
public struct SubscriptionReceiptSnapshot: Equatable, Codable, Sendable {
    public let originalTransactionID: String
    public let productID: String
    public let environment: StoreEnvironment
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let renewalState: RenewalState
    public let autoRenewEnabled: Bool
    public let signedJWSRepresentation: String?

    public init(
        originalTransactionID: String,
        productID: String,
        environment: StoreEnvironment = .production,
        purchaseDate: Date = Date(),
        expirationDate: Date? = nil,
        renewalState: RenewalState = .subscribed,
        autoRenewEnabled: Bool = true,
        signedJWSRepresentation: String? = nil
    ) {
        self.originalTransactionID = originalTransactionID
        self.productID = productID
        self.environment = environment
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.renewalState = renewalState
        self.autoRenewEnabled = autoRenewEnabled
        self.signedJWSRepresentation = signedJWSRepresentation
    }
}

/// Lightweight revenue & funnel snapshot useful for diagnostics and local paywall QA overlays.
public struct RevenueMetricsSnapshot: Equatable, Codable, Sendable {
    public let paywallViews: Int
    public let purchaseAttempts: Int
    public let verifiedPurchases: Int
    public let cancelledPurchases: Int
    public let failedPurchases: Int

    public init(
        paywallViews: Int = 0,
        purchaseAttempts: Int = 0,
        verifiedPurchases: Int = 0,
        cancelledPurchases: Int = 0,
        failedPurchases: Int = 0
    ) {
        self.paywallViews = paywallViews
        self.purchaseAttempts = purchaseAttempts
        self.verifiedPurchases = verifiedPurchases
        self.cancelledPurchases = cancelledPurchases
        self.failedPurchases = failedPurchases
    }

    public var conversionRate: Double {
        guard paywallViews > 0 else { return 0 }
        return Double(verifiedPurchases) / Double(paywallViews)
    }

    public var checkoutCompletionRate: Double {
        guard purchaseAttempts > 0 else { return 0 }
        return Double(verifiedPurchases) / Double(purchaseAttempts)
    }
}
