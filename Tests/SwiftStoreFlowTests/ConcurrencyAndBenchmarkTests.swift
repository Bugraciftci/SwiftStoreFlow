import XCTest
@testable import SwiftStoreFlow

final class ConcurrencyAndBenchmarkTests: XCTestCase {
    func testHighContentionPurchaseDeduplication() async {
        let client = MockStoreClient()
        await client.setPurchaseDelay(80_000_000) // 80ms
        let analytics = RecordingAnalytics()
        let coordinator = EntitlementCoordinator(
            client: client,
            cache: InMemoryEntitlementCache(),
            analytics: analytics
        )

        let outcomes: [Result<PurchaseOutcome, StoreFlowError>] = await withTaskGroup(
            of: Result<PurchaseOutcome, StoreFlowError>.self
        ) { group in
            for _ in 0..<12 {
                group.addTask {
                    await coordinator.purchase(productID: "app.pro.yearly")
                }
            }

            var results: [Result<PurchaseOutcome, StoreFlowError>] = []
            for await outcome in group {
                results.append(outcome)
            }
            return results
        }

        let succeeded = outcomes.filter {
            if case .success(.verified) = $0 { return true }
            return false
        }
        let deduplicated = outcomes.filter { $0 == .failure(.purchaseInProgress) }

        XCTAssertEqual(succeeded.count, 1, "Exactly one purchase should execute under actor isolation")
        XCTAssertEqual(deduplicated.count, 11, "All 11 concurrent re-entrant taps must be deduplicated")
    }

    func testExperimentBucketerThroughputAndDeterminism() {
        let experiment = PaywallExperiment(
            experimentID: "benchmark_paywall_v2",
            variants: [
                PaywallExperimentVariant(id: "control", weight: 50, templateStyle: .standardCards),
                PaywallExperimentVariant(id: "timeline", weight: 50, templateStyle: .trialTimeline)
            ],
            holdoutPercentage: 0.10
        )
        let bucketer = ExperimentBucketer()
        let iterations = 10_000

        let start = CFAbsoluteTimeGetCurrent()
        var firstPass: [String] = []
        firstPass.reserveCapacity(iterations)

        for i in 0..<iterations {
            let assignment = bucketer.assign(userID: "bench-user-\(i)", experiment: experiment)
            firstPass.append(assignment?.variant.id ?? "none")
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        for i in 0..<iterations {
            let repeatAssignment = bucketer.assign(userID: "bench-user-\(i)", experiment: experiment)
            XCTAssertEqual(repeatAssignment?.variant.id ?? "none", firstPass[i])
        }

        XCTAssertLessThan(elapsed, 2.0, "10k FNV-1a bucketings should complete well under 2 seconds (took \(elapsed)s)")
    }
}
