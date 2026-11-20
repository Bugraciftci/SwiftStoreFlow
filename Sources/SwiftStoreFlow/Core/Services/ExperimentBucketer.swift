import Foundation

/// Deterministic, stateless A/B experiment bucketing engine using 64-bit FNV-1a hashing.
/// Guarantees sticky variant assignment across app launches without requiring network round-trips.
public struct ExperimentBucketer: Sendable {
    private let qaOverrides: [String: String]

    public init(qaOverrides: [String: String] = [:]) {
        self.qaOverrides = qaOverrides
    }

    /// Assigns a user deterministically to a variant within the experiment.
    public func assign(userID: String, experiment: PaywallExperiment) -> ExperimentAssignment? {
        guard !experiment.variants.isEmpty else { return nil }

        // QA / TestFlight deterministic override support
        if let forcedVariantID = qaOverrides[experiment.experimentID],
           let forcedVariant = experiment.variants.first(where: { $0.id == forcedVariantID }) {
            return ExperimentAssignment(
                experimentID: experiment.experimentID,
                variant: forcedVariant,
                isHoldout: false,
                bucketValue: 0.0
            )
        }

        let normalized = Self.normalizedHash(key: "\(experiment.experimentID)::\(userID)")

        if experiment.holdoutPercentage > 0, normalized < experiment.holdoutPercentage {
            return ExperimentAssignment(
                experimentID: experiment.experimentID,
                variant: experiment.variants[0],
                isHoldout: true,
                bucketValue: normalized
            )
        }

        // Re-map remaining probability mass [holdout, 1.0) onto [0.0, 1.0)
        let activeSpan = max(1.0 - experiment.holdoutPercentage, Double.leastNonzeroMagnitude)
        let adjusted = min(max((normalized - experiment.holdoutPercentage) / activeSpan, 0.0), 0.999999999)

        let totalWeight = experiment.variants.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return ExperimentAssignment(
                experimentID: experiment.experimentID,
                variant: experiment.variants[0],
                isHoldout: false,
                bucketValue: normalized
            )
        }

        var cumulative = 0.0
        for variant in experiment.variants {
            cumulative += variant.weight / totalWeight
            if adjusted < cumulative {
                return ExperimentAssignment(
                    experimentID: experiment.experimentID,
                    variant: variant,
                    isHoldout: false,
                    bucketValue: normalized
                )
            }
        }

        return ExperimentAssignment(
            experimentID: experiment.experimentID,
            variant: experiment.variants[experiment.variants.count - 1],
            isHoldout: false,
            bucketValue: normalized
        )
    }

    /// Computes a stable FNV-1a 64-bit hash with SplitMix64 avalanche finalizer normalized into [0.0, 1.0).
    static func normalizedHash(key: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        // SplitMix64 avalanche finalizer eliminates sequential-ID clustering
        hash ^= hash >> 30
        hash &*= 0xbf58476d1ce4e5b9
        hash ^= hash >> 27
        hash &*= 0x94d049bb133111eb
        hash ^= hash >> 31
        // Use upper 53 bits for exact IEEE 754 Double precision
        let mantissa = hash >> 11
        return Double(mantissa) / Double(UInt64(1) << 53)
    }
}
