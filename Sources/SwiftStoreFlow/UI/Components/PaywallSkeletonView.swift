import SwiftUI

/// Animated skeleton placeholder cards rendered while StoreKit fetches localized pricing.
public struct PaywallSkeletonView: View {
    @State private var isPulsing = false

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 120, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: 170, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.24))
                        .frame(width: 58, height: 20)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(isPulsing ? 0.55 : 1.0)
            }
        }
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear { isPulsing = true }
        .accessibilityLabel("Loading subscription plans")
    }
}
