import Foundation

/// Visual presentation layout rendered by PaywallView.
public enum PaywallTemplateStyle: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case standardCards
    case trialTimeline
    case featureMatrix
}

/// Comparison row used by the FeatureComparisonMatrixView template.
public struct PaywallFeatureRow: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let symbolName: String
    public let includedInFree: Bool
    public let includedInPro: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        symbolName: String = "sparkles",
        includedInFree: Bool,
        includedInPro: Bool = true
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.includedInFree = includedInFree
        self.includedInPro = includedInPro
    }
}

/// Single step in a transparent free-trial timeline (Day 1 -> Reminder -> Billing).
public struct TrialTimelineMilestone: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let dayLabel: String
    public let title: String
    public let detail: String
    public let symbolName: String

    public init(
        id: String = UUID().uuidString,
        dayLabel: String,
        title: String,
        detail: String,
        symbolName: String
    ) {
        self.id = id
        self.dayLabel = dayLabel
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
    }

    public static let defaultSevenDayTrial: [TrialTimelineMilestone] = [
        TrialTimelineMilestone(
            id: "day-0",
            dayLabel: "Today",
            title: "Unlock Full Pro Access",
            detail: "Instant access to all AI engines, widgets, and CarPlay sync.",
            symbolName: "lock.open.fill"
        ),
        TrialTimelineMilestone(
            id: "day-5",
            dayLabel: "Day 5",
            title: "Trial Reminder Notification",
            detail: "We remind you 48 hours before your free trial concludes.",
            symbolName: "bell.badge.fill"
        ),
        TrialTimelineMilestone(
            id: "day-7",
            dayLabel: "Day 7",
            title: "Subscription Begins",
            detail: "Cancel anytime in iOS Settings with zero commitment.",
            symbolName: "checkmark.seal.fill"
        )
    ]
}

/// Configurable A/B paywall treatment variant.
public struct PaywallExperimentVariant: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let weight: Double
    public let templateStyle: PaywallTemplateStyle
    public let headline: String
    public let ctaTitle: String
    public let defaultBillingPeriod: SubscriptionPlan.BillingPeriod
    public let highlightBadgeText: String?

    public init(
        id: String,
        weight: Double = 1.0,
        templateStyle: PaywallTemplateStyle = .standardCards,
        headline: String = "Unlock Pro Access",
        ctaTitle: String = "Continue",
        defaultBillingPeriod: SubscriptionPlan.BillingPeriod = .yearly,
        highlightBadgeText: String? = nil
    ) {
        self.id = id
        self.weight = max(0, weight)
        self.templateStyle = templateStyle
        self.headline = headline
        self.ctaTitle = ctaTitle
        self.defaultBillingPeriod = defaultBillingPeriod
        self.highlightBadgeText = highlightBadgeText
    }
}

/// Complete A/B experiment specification with optional holdout traffic percentage.
public struct PaywallExperiment: Equatable, Codable, Sendable {
    public let experimentID: String
    public let variants: [PaywallExperimentVariant]
    public let holdoutPercentage: Double

    public init(
        experimentID: String,
        variants: [PaywallExperimentVariant],
        holdoutPercentage: Double = 0.0
    ) {
        self.experimentID = experimentID
        self.variants = variants
        self.holdoutPercentage = min(max(holdoutPercentage, 0.0), 1.0)
    }
}

/// Deterministic assignment output bound to a specific user and experiment.
public struct ExperimentAssignment: Equatable, Codable, Sendable {
    public let experimentID: String
    public let variant: PaywallExperimentVariant
    public let isHoldout: Bool
    public let bucketValue: Double

    public init(
        experimentID: String,
        variant: PaywallExperimentVariant,
        isHoldout: Bool,
        bucketValue: Double
    ) {
        self.experimentID = experimentID
        self.variant = variant
        self.isHoldout = isHoldout
        self.bucketValue = bucketValue
    }
}
