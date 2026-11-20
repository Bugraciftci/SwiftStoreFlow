import SwiftUI

/// ViewModifier that gates premium SwiftUI views behind a verified entitlement tier.
public struct EntitlementGateModifier<PaywallContent: View>: ViewModifier {
    private let entitlement: EntitlementState
    private let requiredTier: EntitlementTier
    private let paywallBuilder: () -> PaywallContent

    public init(
        entitlement: EntitlementState,
        requiredTier: EntitlementTier = .pro,
        @ViewBuilder paywall: @escaping () -> PaywallContent
    ) {
        self.entitlement = entitlement
        self.requiredTier = requiredTier
        self.paywallBuilder = paywall
    }

    public func body(content: Content) -> some View {
        if entitlement.hasAccess(to: requiredTier) {
            content
        } else {
            paywallBuilder()
        }
    }
}

public extension View {
    func requiresEntitlement<PaywallContent: View>(
        _ entitlement: EntitlementState,
        tier: EntitlementTier = .pro,
        @ViewBuilder paywall: @escaping () -> PaywallContent
    ) -> some View {
        modifier(
            EntitlementGateModifier(
                entitlement: entitlement,
                requiredTier: tier,
                paywall: paywall
            )
        )
    }
}
