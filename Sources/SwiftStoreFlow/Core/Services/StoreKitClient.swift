import Foundation
import StoreKit

/// Production StoreKit 2 client bridging Apple transactions into typed SwiftStoreFlow models.
public final class StoreKitClient: StoreClientProtocol, @unchecked Sendable {
    private let tierMapping: [String: EntitlementTier]

    public init(tierMapping: [String: EntitlementTier] = [:]) {
        self.tierMapping = tierMapping
    }

    public func fetchPlans(productIDs: [String]) async throws -> [SubscriptionPlan] {
        let products = try await Product.products(for: productIDs)
        guard !products.isEmpty else {
            throw StoreFlowError.productsUnavailable
        }

        return products
            .sorted { $0.price < $1.price }
            .map { product in
                SubscriptionPlan(
                    id: product.id,
                    title: product.displayName,
                    subtitle: product.description,
                    displayPrice: product.displayPrice,
                    priceDecimal: product.price,
                    billingPeriod: Self.mapPeriod(product),
                    trialDescription: Self.trialDescription(for: product),
                    tier: tierMapping[product.id] ?? .pro
                )
            }
    }

    public func purchase(productID: String) async throws -> PurchaseOutcome {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw StoreFlowError.productsUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.verify(verification)
            await transaction.finish()
            let entitlement = try await currentEntitlement()
            return .verified(entitlement)
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            throw StoreFlowError.unknown("Unhandled StoreKit purchase result.")
        }
    }

    public func currentEntitlement() async throws -> EntitlementState {
        var activeIDs = Set<String>()
        var highestTier: EntitlementTier = .free
        var latestExpiration: Date?

        for await verification in Transaction.currentEntitlements {
            guard let transaction = try? Self.verify(verification) else { continue }
            guard transaction.revocationDate == nil else { continue }

            activeIDs.insert(transaction.productID)
            let tier = tierMapping[transaction.productID] ?? .pro
            if tier > highestTier {
                highestTier = tier
            }
            if let expiry = transaction.expirationDate {
                if let existing = latestExpiration {
                    latestExpiration = max(existing, expiry)
                } else {
                    latestExpiration = expiry
                }
            }
        }

        return EntitlementState(
            tier: activeIDs.isEmpty ? .free : highestTier,
            activeProductIDs: activeIDs,
            expirationDate: latestExpiration,
            isInGracePeriod: false,
            lastVerifiedAt: Date()
        )
    }

    public func restorePurchases() async throws -> EntitlementState {
        try await AppStore.sync()
        return try await currentEntitlement()
    }

    private static func verify<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .verified(let signed):
            return signed
        case .unverified(_, let error):
            throw StoreFlowError.verificationFailed(error.localizedDescription)
        }
    }

    private static func mapPeriod(_ product: Product) -> SubscriptionPlan.BillingPeriod {
        guard let unit = product.subscription?.subscriptionPeriod.unit else {
            return .lifetime
        }
        switch unit {
        case .day, .week: return .weekly
        case .month: return .monthly
        case .year: return .yearly
        @unknown default: return .monthly
        }
    }

    private static func trialDescription(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            return nil
        }
        let count = offer.period.value
        let unitLabel: String
        switch offer.period.unit {
        case .day: unitLabel = count == 1 ? "day" : "days"
        case .week: unitLabel = count == 1 ? "week" : "weeks"
        case .month: unitLabel = count == 1 ? "month" : "months"
        case .year: unitLabel = count == 1 ? "year" : "years"
        @unknown default: unitLabel = "days"
        }
        return "\(count)-\(unitLabel) free trial"
    }
}
