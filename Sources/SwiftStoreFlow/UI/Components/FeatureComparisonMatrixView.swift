import SwiftUI

/// Side-by-side Free vs. Pro feature comparison matrix supporting Dynamic Type & VoiceOver.
public struct FeatureComparisonMatrixView: View {
    private let rows: [PaywallFeatureRow]

    public init(rows: [PaywallFeatureRow] = Self.defaultRows) {
        self.rows = rows
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feature")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Free")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48)
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Label(row.title, systemImage: row.symbolName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer()
                    statusIcon(included: row.includedInFree, accent: false)
                        .frame(width: 48)
                    statusIcon(included: row.includedInPro, accent: true)
                        .frame(width: 48)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                Divider()
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func statusIcon(included: Bool, accent: Bool) -> some View {
        Image(systemName: included ? "checkmark.circle.fill" : "minus")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(included ? (accent ? Color.accentColor : Color.secondary) : Color.secondary.opacity(0.45))
            .accessibilityLabel(included ? "Included" : "Not included")
    }

    public static let defaultRows: [PaywallFeatureRow] = [
        PaywallFeatureRow(id: "core", title: "Core Daily Workflows", symbolName: "bolt.fill", includedInFree: true, includedInPro: true),
        PaywallFeatureRow(id: "ai", title: "Unlimited AI Processing", symbolName: "sparkles", includedInFree: false, includedInPro: true),
        PaywallFeatureRow(id: "offline", title: "Offline Keychain Entitlements", symbolName: "lock.shield.fill", includedInFree: false, includedInPro: true),
        PaywallFeatureRow(id: "carplay", title: "CarPlay & WidgetKit Sync", symbolName: "car.fill", includedInFree: false, includedInPro: true)
    ]
}
