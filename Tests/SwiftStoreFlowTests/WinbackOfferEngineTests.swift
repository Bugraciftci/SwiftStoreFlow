import XCTest
@testable import SwiftStoreFlow

final class WinbackOfferEngineTests: XCTestCase {
    private let engine = WinbackOfferEngine()

    func testSubscribedWithAutoRenewOffTriggersLoyaltySaveOffer() {
        let receipt = SubscriptionReceiptSnapshot(
            originalTransactionID: "tx-100",
            productID: "com.app.pro.yearly",
            renewalState: .subscribed,
            autoRenewEnabled: false
        )

        let rec = engine.evaluateRecovery(for: receipt)
        XCTAssertEqual(rec.strategy, .autoRenewCancelledSaveOffer)
        XCTAssertEqual(rec.recommendedOffer?.offerID, "com.storeflow.save.loyalty40")
        XCTAssertGreaterThan(rec.estimatedLTVLiftMultiplier, 1.3)
    }

    func testRecentvsDeepExpiredSubscriptionSelectsDistinctWinbackOffers() {
        let now = Date()
        let recentExpired = SubscriptionReceiptSnapshot(
            originalTransactionID: "tx-200",
            productID: "com.app.pro.monthly",
            expirationDate: now.addingTimeInterval(-10 * 86_400),
            renewalState: .expired,
            autoRenewEnabled: false
        )
        let deepExpired = SubscriptionReceiptSnapshot(
            originalTransactionID: "tx-201",
            productID: "com.app.pro.monthly",
            expirationDate: now.addingTimeInterval(-60 * 86_400),
            renewalState: .expired,
            autoRenewEnabled: false
        )

        let recentRec = engine.evaluateRecovery(for: recentExpired, now: now)
        let deepRec = engine.evaluateRecovery(for: deepExpired, now: now)

        XCTAssertEqual(recentRec.strategy, .recentLapseWinback50Percent)
        XCTAssertEqual(recentRec.recommendedOffer?.kind, .winBack)
        XCTAssertEqual(deepRec.strategy, .deepLapseReactivationTrial)
        XCTAssertEqual(deepRec.recommendedOffer?.durationDays, 14)
    }

    func testABExperimentComparisonCalculatesConversionLiftAndDetectsSRM() {
        let control = RevenueMetricsSnapshot(paywallViews: 1000, purchaseAttempts: 140, verifiedPurchases: 100)
        let treatmentHealthy = RevenueMetricsSnapshot(paywallViews: 1010, purchaseAttempts: 180, verifiedPurchases: 135)

        let reportHealthy = engine.compareExperimentVariants(control: control, treatment: treatmentHealthy)
        XCTAssertFalse(reportHealthy.hasSampleRatioMismatchWarning)
        XCTAssertGreaterThan(reportHealthy.relativeConversionLiftPercent, 30.0)

        let treatmentSkewed = RevenueMetricsSnapshot(paywallViews: 650, purchaseAttempts: 110, verifiedPurchases: 90)
        let reportSRM = engine.compareExperimentVariants(control: control, treatment: treatmentSkewed)
        XCTAssertTrue(reportSRM.hasSampleRatioMismatchWarning)
    }
}
