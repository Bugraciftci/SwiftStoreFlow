import SwiftUI

/// Adaptive, HIG-compliant SwiftUI Paywall view driven by PaywallViewModel.
public struct PaywallView: View {
    @ObservedObject private var viewModel: PaywallViewModel
    private let headline: String
    private let benefits: [String]
    private let onDismiss: (() -> Void)?

    public init(
        viewModel: PaywallViewModel,
        headline: String = "Unlock Pro Access",
        benefits: [String] = [
            "Unlimited AI generations & priority processing",
            "Offline-first encrypted Keychain entitlements",
            "Sync across iPhone, iPad, and CarPlay"
        ],
        onDismiss: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.headline = headline
        self.benefits = benefits
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                benefitsSection
                plansSection
                ctaSection
            }
            .padding(24)
        }
        .task {
            await viewModel.onAppear()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(headline)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            if case .failed(let message) = viewModel.phase {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(benefits, id: \.self) { benefit in
                Label(benefit, systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var plansSection: some View {
        let monthlyPrice = viewModel.plans.first(where: { $0.billingPeriod == .monthly })?.priceDecimal

        return VStack(spacing: 12) {
            if viewModel.phase == .loading && viewModel.plans.isEmpty {
                ProgressView("Loading plans...")
                    .padding(.vertical, 24)
            } else {
                ForEach(viewModel.plans) { plan in
                    PlanOptionCard(
                        plan: plan,
                        isSelected: viewModel.selectedPlanID == plan.id,
                        savingsPercent: monthlyPrice.flatMap { plan.savingsPercentage(comparedToMonthly: $0) }
                    ) {
                        Task { await viewModel.selectPlan(plan.id) }
                    }
                }
            }
        }
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.purchaseSelectedPlan() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.phase == .purchasing {
                        ProgressView()
                    }
                    Text(viewModel.phase == .purchased ? "Pro Active" : "Continue")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBusy || viewModel.selectedPlanID == nil || viewModel.phase == .purchased)

            HStack(spacing: 20) {
                Button("Restore Purchases") {
                    Task { await viewModel.restorePurchases() }
                }
                .font(.footnote)
                .disabled(viewModel.isBusy)

                if let onDismiss {
                    Button("Not Now", action: onDismiss)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
