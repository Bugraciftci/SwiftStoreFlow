import XCTest
@testable import SwiftStoreFlow

final class ExperimentBucketerTests: XCTestCase {
    private let sampleExperiment = PaywallExperiment(
        experimentID: "paywall_q4_2026",
        variants: [
            PaywallExperimentVariant(
                id: "control_cards",
                weight: 50,
                templateStyle: .standardCards,
                headline: "Go Pro Today",
                ctaTitle: "Continue"
            ),
            PaywallExperimentVariant(
                id: "trial_timeline",
                weight: 50,
                templateStyle: .trialTimeline,
                headline: "Try 7 Days Free",
                ctaTitle: "Start Free Trial"
            )
        ],
        holdoutPercentage: 0.10
    )

    func testAssignmentIsDeterministicAcrossCalls() {
        let bucketer = ExperimentBucketer()
        let first = bucketer.assign(userID: "user-42-istanbul", experiment: sampleExperiment)
        let second = bucketer.assign(userID: "user-42-istanbul", experiment: sampleExperiment)

        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    func testTrafficDistributionMatchesConfiguredWeightsWithinTolerance() {
        let bucketer = ExperimentBucketer()
        var holdoutCount = 0
        var controlCount = 0
        var timelineCount = 0
        let total = 5_000

        for i in 0..<total {
            guard let assignment = bucketer.assign(userID: "synthetic-user-\(i)", experiment: sampleExperiment) else {
                XCTFail("Expected non-nil assignment")
                return
            }
            if assignment.isHoldout {
                holdoutCount += 1
            } else if assignment.variant.id == "control_cards" {
                controlCount += 1
            } else if assignment.variant.id == "trial_timeline" {
                timelineCount += 1
            }
        }

        let holdoutRatio = Double(holdoutCount) / Double(total)
        let controlRatio = Double(controlCount) / Double(total - holdoutCount)
        let timelineRatio = Double(timelineCount) / Double(total - holdoutCount)

        XCTAssertEqual(holdoutRatio, 0.10, accuracy: 0.025)
        XCTAssertEqual(controlRatio, 0.50, accuracy: 0.03)
        XCTAssertEqual(timelineRatio, 0.50, accuracy: 0.03)
    }

    func testQAOverrideForcesSpecificVariantAndBypassesHoldout() {
        let bucketer = ExperimentBucketer(qaOverrides: ["paywall_q4_2026": "trial_timeline"])
        let assignment = bucketer.assign(userID: "any-qa-tester", experiment: sampleExperiment)

        XCTAssertEqual(assignment?.variant.id, "trial_timeline")
        XCTAssertEqual(assignment?.isHoldout, false)
    }

    func testEmptyExperimentReturnsNil() {
        let bucketer = ExperimentBucketer()
        let empty = PaywallExperiment(experimentID: "empty", variants: [])
        XCTAssertNil(bucketer.assign(userID: "u1", experiment: empty))
    }

    @MainActor
    func testViewModelAppliesAssignedExperimentVariantAndLogsExposure() async {
        let client = MockStoreClient()
        let analytics = RecordingAnalytics()
        let coordinator = EntitlementCoordinator(
            client: client,
            cache: InMemoryEntitlementCache(),
            analytics: analytics
        )
        let bucketer = ExperimentBucketer(qaOverrides: ["paywall_q4_2026": "trial_timeline"])
        let viewModel = PaywallViewModel(
            coordinator: coordinator,
            productIDs: ["app.pro.monthly", "app.pro.yearly"],
            placement: "onboarding_v2",
            analytics: analytics,
            experiment: sampleExperiment,
            bucketer: bucketer,
            userID: "qa-user-1"
        )

        await viewModel.onAppear()

        XCTAssertEqual(viewModel.templateStyle, .trialTimeline)
        XCTAssertEqual(viewModel.headline, "Try 7 Days Free")
        XCTAssertEqual(viewModel.ctaTitle, "Start Free Trial")

        let events = await analytics.allEvents()
        XCTAssertTrue(events.contains(.experimentExposed(
            experimentID: "paywall_q4_2026",
            variantID: "trial_timeline",
            isHoldout: false
        )))
    }
}
