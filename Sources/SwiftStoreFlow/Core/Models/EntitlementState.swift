import Foundation

/// Access level granted by verified StoreKit entitlements.
public enum EntitlementTier: Int, Comparable, Codable, Sendable, Hashable {
    case free = 0
    case pro = 1
    case studio = 2

    public static func < (lhs: EntitlementTier, rhs: EntitlementTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Snapshot of the user's verified subscription entitlement.
public struct EntitlementState: Equatable, Codable, Sendable {
    public let tier: EntitlementTier
    public let activeProductIDs: Set<String>
    public let expirationDate: Date?
    public let isInGracePeriod: Bool
    public let lastVerifiedAt: Date

    public init(
        tier: EntitlementTier,
        activeProductIDs: Set<String>,
        expirationDate: Date? = nil,
        isInGracePeriod: Bool = false,
        lastVerifiedAt: Date = Date()
    ) {
        self.tier = tier
        self.activeProductIDs = activeProductIDs
        self.expirationDate = expirationDate
        self.isInGracePeriod = isInGracePeriod
        self.lastVerifiedAt = lastVerifiedAt
    }

    public static let free = EntitlementState(
        tier: .free,
        activeProductIDs: [],
        expirationDate: nil,
        isInGracePeriod: false
    )

    public var isProActive: Bool {
        hasAccess(to: .pro)
    }

    public func hasAccess(to requiredTier: EntitlementTier, referenceDate: Date = Date()) -> Bool {
        guard tier >= requiredTier else { return false }
        if let expirationDate, !isInGracePeriod {
            return expirationDate > referenceDate
        }
        return true
    }
}

/// Outcome returned by a StoreKit purchase attempt.
public enum PurchaseOutcome: Equatable, Sendable {
    case verified(EntitlementState)
    case pending
    case userCancelled
}
