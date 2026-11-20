import SwiftUI

/// Selectable subscription plan card supporting Dark Mode, Dynamic Type, and VoiceOver.
public struct PlanOptionCard: View {
    private let plan: SubscriptionPlan
    private let isSelected: Bool
    private let savingsPercent: Int?
    private let onSelect: () -> Void

    public init(
        plan: SubscriptionPlan,
        isSelected: Bool,
        savingsPercent: Int? = nil,
        onSelect: @escaping () -> Void
    ) {
        self.plan = plan
        self.isSelected = isSelected
        self.savingsPercent = savingsPercent
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge = plan.badgeText ?? savingsPercent.map({ "SAVE \($0)%" }) {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text(plan.trialDescription ?? plan.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.displayPrice)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.primary)

                    Text(plan.billingPeriod.localizedSuffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
