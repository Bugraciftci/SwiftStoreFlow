import Foundation

/// Actionable churn-prevention or win-back strategy synthesized from a user's receipt lifecycle.
public struct ChurnRecoveryRecommendation: Equatable, Codable, Sendable {
    public enum StrategyKind: String, Codable, Sendable, Equatable {
        case noneActive
        case autoRenewCancelledSaveOffer
        case paymentMethodUpdateGrace
        case billingRetryRetentionOffer
        case recentLapseWinback50Percent
        case deepLapseReactivationTrial
    }

    public let strategy: StrategyKind
    public let bannerTitle: String
    public let bannerSubtitle: String
    public let recommendedOffer: PromotionalOfferMetadata?
    public let estimatedLTVLiftMultiplier: Double

    public init(
        strategy: StrategyKind,
        bannerTitle: String,
        bannerSubtitle: String,
        recommendedOffer: PromotionalOfferMetadata?,
        estimatedLTVLiftMultiplier: Double
    ) {
        self.strategy = strategy
        self.bannerTitle = bannerTitle
        self.bannerSubtitle = bannerSubtitle
        self.recommendedOffer = recommendedOffer
        self.estimatedLTVLiftMultiplier = estimatedLTVLiftMultiplier
    }
}

/// Statistical health and LTV comparison between two paywall A/B experiment variants.
public struct PaywallABComparisonReport: Equatable, Codable, Sendable {
    public let controlMetrics: RevenueMetricsSnapshot
    public let treatmentMetrics: RevenueMetricsSnapshot
    public let relativeConversionLiftPercent: Double
    public let sampleRatioMismatchChiSquare: Double
    public let hasSampleRatioMismatchWarning: Bool
    public let projectedARPPU: Double
}

/// Deterministic churn-prevention, win-back offer selector, and A/B SRM guard engine.
public struct WinbackOfferEngine: Sendable {
    public init() {}

    /// Evaluates a subscription receipt snapshot and selects the highest-LTV recovery or win-back offer.
    public func evaluateRecovery(
        for receipt: SubscriptionReceiptSnapshot,
        now: Date = Date()
    ) -> ChurnRecoveryRecommendation {
        switch receipt.renewalState {
        case .subscribed:
            if !receipt.autoRenewEnabled {
                return ChurnRecoveryRecommendation(
                    strategy: .autoRenewCancelledSaveOffer,
                    bannerTitle: "Keep Your Pro Benefits — 40% Off Next Year",
                    bannerSubtitle: "Auto-renew is currently turned off. Lock in our loyalty rate before your period ends.",
                    recommendedOffer: PromotionalOfferMetadata(
                        offerID: "com.storeflow.save.loyalty40",
                        kind: .payUpFront,
                        discountedDisplayPrice: "$29.99/yr",
                        durationDays: 365,
                        isEligible: true
                    ),
                    estimatedLTVLiftMultiplier: 1.42
                )
            }
            return ChurnRecoveryRecommendation(
                strategy: .noneActive,
                bannerTitle: "Active Pro Subscription",
                bannerSubtitle: "All entitlements verified and active.",
                recommendedOffer: nil,
                estimatedLTVLiftMultiplier: 1.0
            )

        case .inGracePeriod:
            return ChurnRecoveryRecommendation(
                strategy: .paymentMethodUpdateGrace,
                bannerTitle: "Update Payment Method to Keep Pro Active",
                bannerSubtitle: "Your premium access remains unlocked during your App Store billing grace period.",
                recommendedOffer: nil,
                estimatedLTVLiftMultiplier: 1.25
            )

        case .inBillingRetry:
            return ChurnRecoveryRecommendation(
                strategy: .billingRetryRetentionOffer,
                bannerTitle: "Billing Retry Detected — Claim 1 Month at $1.99",
                bannerSubtitle: "Resolve your Apple ID payment method and continue seamlessly.",
                recommendedOffer: PromotionalOfferMetadata(
                    offerID: "com.storeflow.retry.bridge",
                    kind: .payAsYouGo,
                    discountedDisplayPrice: "$1.99/mo",
                    durationDays: 30,
                    isEligible: true
                ),
                estimatedLTVLiftMultiplier: 1.35
            )

        case .expired, .revoked:
            let elapsedDays: Int
            if let exp = receipt.expirationDate {
                elapsedDays = max(0, Int(now.timeIntervalSince(exp) / 86_400))
            } else {
                elapsedDays = 14
            }

            if elapsedDays <= 30 {
                return ChurnRecoveryRecommendation(
                    strategy: .recentLapseWinback50Percent,
                    bannerTitle: "Welcome Back — 50% Off Annual Pro",
                    bannerSubtitle: "Special App Store win-back offer for returning subscribers.",
                    recommendedOffer: PromotionalOfferMetadata(
                        offerID: "com.storeflow.winback.50off",
                        kind: .winBack,
                        discountedDisplayPrice: "$24.99/yr",
                        durationDays: 365,
                        isEligible: true
                    ),
                    estimatedLTVLiftMultiplier: 1.58
                )
            } else {
                return ChurnRecoveryRecommendation(
                    strategy: .deepLapseReactivationTrial,
                    bannerTitle: "Try Our All-New v2.0 Studio Free for 14 Days",
                    bannerSubtitle: "Extended reactivation trial + discounted renewal.",
                    recommendedOffer: PromotionalOfferMetadata(
                        offerID: "com.storeflow.winback.14day",
                        kind: .winBack,
                        discountedDisplayPrice: "14 Days Free",
                        durationDays: 14,
                        isEligible: true
                    ),
                    estimatedLTVLiftMultiplier: 1.48
                )
            }
        }
    }

    /// Compares Control and Treatment funnel snapshots, calculating conversion lift, ARPPU, and Chi-Square SRM.
    public func compareExperimentVariants(
        control: RevenueMetricsSnapshot,
        treatment: RevenueMetricsSnapshot,
        expectedTreatmentSplit: Double = 0.5,
        averagePlanPriceUSD: Double = 39.99
    ) -> PaywallABComparisonReport {
        let baseCR = control.conversionRate
        let treatCR = treatment.conversionRate
        let liftPercent: Double
        if baseCR > 0 {
            liftPercent = ((treatCR - baseCR) / baseCR) * 100.0
        } else {
            liftPercent = 0.0
        }

        let totalViews = Double(control.paywallViews + treatment.paywallViews)
        var chiSquare = 0.0
        if totalViews > 0 {
            let expectedTreat = totalViews * min(max(expectedTreatmentSplit, 0.01), 0.99)
            let expectedCtrl = totalViews - expectedTreat
            let diffTreat = Double(treatment.paywallViews) - expectedTreat
            let diffCtrl = Double(control.paywallViews) - expectedCtrl
            chiSquare = ((diffTreat * diffTreat) / expectedTreat) + ((diffCtrl * diffCtrl) / expectedCtrl)
        }

        // Critical value for 1 degree of freedom at p = 0.01 is 6.635
        let hasSRM = chiSquare >= 6.635
        let arppu = treatCR * averagePlanPriceUSD

        return PaywallABComparisonReport(
            controlMetrics: control,
            treatmentMetrics: treatment,
            relativeConversionLiftPercent: (liftPercent * 100).rounded() / 100,
            sampleRatioMismatchChiSquare: (chiSquare * 1000).rounded() / 1000,
            hasSampleRatioMismatchWarning: hasSRM,
            projectedARPPU: (arppu * 100).rounded() / 100
        )
    }
}
