import Foundation

/// Represents a purchasable subscription or one-time product displayed on a paywall.
public struct SubscriptionPlan: Identifiable, Equatable, Hashable, Sendable, Codable {
    public enum BillingPeriod: String, Sendable, Codable, Hashable {
        case weekly
        case monthly
        case yearly
        case lifetime

        public var localizedSuffix: String {
            switch self {
            case .weekly: return "/wk"
            case .monthly: return "/mo"
            case .yearly: return "/yr"
            case .lifetime: return " once"
            }
        }
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let displayPrice: String
    public let priceDecimal: Decimal
    public let billingPeriod: BillingPeriod
    public let badgeText: String?
    public let trialDescription: String?
    public let promotionalOffer: PromotionalOfferMetadata?
    public let tier: EntitlementTier

    public init(
        id: String,
        title: String,
        subtitle: String,
        displayPrice: String,
        priceDecimal: Decimal,
        billingPeriod: BillingPeriod,
        badgeText: String? = nil,
        trialDescription: String? = nil,
        promotionalOffer: PromotionalOfferMetadata? = nil,
        tier: EntitlementTier = .pro
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.displayPrice = displayPrice
        self.priceDecimal = priceDecimal
        self.billingPeriod = billingPeriod
        self.badgeText = badgeText
        self.trialDescription = trialDescription
        self.promotionalOffer = promotionalOffer
        self.tier = tier
    }

    /// Computes percentage savings compared to a baseline monthly plan.
    public func savingsPercentage(comparedToMonthly monthlyPrice: Decimal) -> Int? {
        guard billingPeriod == .yearly, monthlyPrice > 0 else { return nil }
        let annualized = monthlyPrice * 12
        guard annualized > priceDecimal else { return nil }
        let ratio = NSDecimalNumber(decimal: (annualized - priceDecimal) / annualized).doubleValue
        return Int((ratio * 100).rounded())
    }
}
