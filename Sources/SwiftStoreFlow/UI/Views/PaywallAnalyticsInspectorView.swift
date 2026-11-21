#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI QA and Product Growth overlay for inspecting A/B paywall conversion lift, SRM guards, and win-back banners.
public struct PaywallAnalyticsInspectorView: View {
    public let report: PaywallABComparisonReport
    public let recommendation: ChurnRecoveryRecommendation

    public init(
        report: PaywallABComparisonReport,
        recommendation: ChurnRecoveryRecommendation
    ) {
        self.report = report
        self.recommendation = recommendation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STOREKIT 2 A/B & WIN-BACK TELEMETRY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.cyan)
                Spacer()
                Text(report.hasSampleRatioMismatchWarning ? "SRM WARNING" : "SRM HEALTHY")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(
                            report.hasSampleRatioMismatchWarning
                                ? Color.red.opacity(0.22)
                                : Color.green.opacity(0.22)
                        )
                    )
                    .foregroundStyle(report.hasSampleRatioMismatchWarning ? Color.red : Color.green)
            }

            HStack(spacing: 12) {
                metricBox(
                    title: "Control CR",
                    value: String(format: "%.1f%%", report.controlMetrics.conversionRate * 100)
                )
                metricBox(
                    title: "Treatment CR",
                    value: String(format: "%.1f%%", report.treatmentMetrics.conversionRate * 100)
                )
                metricBox(
                    title: "Relative Lift",
                    value: String(format: "%+.1f%%", report.relativeConversionLiftPercent)
                )
                metricBox(
                    title: "Est. ARPU",
                    value: String(format: "$%.2f", report.projectedARPPU)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.bannerTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white)
                Text(recommendation.bannerSubtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.72))
                if let offer = recommendation.recommendedOffer {
                    Text("Offer ID: \(offer.offerID) · \(offer.discountedDisplayPrice) · \(recommendation.estimatedLTVLiftMultiplier, specifier: "%.2f")x LTV Lift")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.13))
        )
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.6))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
#endif
