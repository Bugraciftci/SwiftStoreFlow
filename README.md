<div align="center">
  <img src="./assets/banner.svg" width="100%" alt="SwiftStoreFlow v2.0 Banner" />
</div>

<p align="center">
  <img src="https://img.shields.io/badge/Swift_6.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/iOS_17%2B_%7C_macOS_14%2B-0071E3?style=for-the-badge&logo=apple&logoColor=white" alt="Platforms" />
  <img src="https://img.shields.io/badge/Tests-21_Passing-22C55E?style=for-the-badge" alt="Tests" />
  <img src="https://img.shields.io/badge/License-MIT-38BDF8?style=for-the-badge" alt="License" />
</p>

Production-grade **Swift 6 & SwiftUI StoreKit 2** monetization, A/B paywall experimentation, and offline-first Keychain entitlement architecture extracted from commercial App Store apps.

## Architecture

```mermaid
flowchart LR
    UI["SwiftUI PaywallView<br/>Standard · Trial Timeline · Feature Matrix"] --> VM["@MainActor PaywallViewModel<br/>(@Published State Machine)"]
    AB["ExperimentBucketer<br/>FNV-1a Deterministic A/B"] --> VM
    VM --> C["actor EntitlementCoordinator<br/>(Purchase Deduplication)"]
    C --> SK["StoreClientProtocol<br/>StoreKit 2 / Mock"]
    C --> KC["EntitlementCacheProtocol<br/>Keychain / InMemory Actor"]
    OBS["actor TransactionObserverActor<br/>AsyncStream + JWS Validator"] --> KC
    OBS --> VM
    C & VM --> AN["PaywallAnalyticsProtocol<br/>Funnel & Exposure Events"]
```

## What's Inside (v2.0)

- **Rich Subscription Lifecycle Models (`SubscriptionLifecycle.swift`):** Models `RenewalState` (`subscribed`, `inGracePeriod`, `inBillingRetry`, `expired`, `revoked`), `PromotionalOfferMetadata` (introductory trials, win-back offers), `SubscriptionReceiptSnapshot` (JWS), and `RevenueMetricsSnapshot`.
- **Deterministic A/B Paywall Engine (`ExperimentBucketer.swift`):** Stateless 64-bit FNV-1a bucketing with weighted variants, holdout cohorts, QA/TestFlight overrides, and automatic exposure tracking.
- **Live Transaction Stream & JWS Validation (`TransactionObserverActor.swift`):** Multi-consumer `AsyncStream<EntitlementUpdateEvent>` bridging StoreKit 2 updates through a pluggable `ReceiptValidatorProtocol` with `.strictOnline` or `.allowCachedGraceWindow` offline policies.
- **3 Adaptive SwiftUI Paywall Templates:** `StandardCards`, `TrialTimelineView` (Day 1 → Reminder → Billing), and `FeatureComparisonMatrixView` + animated `PaywallSkeletonView` and billing-retry alert banner.
- **Strict Swift 6 Concurrency:** Full `Sendable` value types, actor-isolated purchase deduplication, Keychain storage (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), and zero data-race warnings.

## Quick Usage

```swift
import SwiftUI
import SwiftStoreFlow

let experiment = PaywallExperiment(
    experimentID: "onboarding_paywall_v2",
    variants: [
        PaywallExperimentVariant(id: "control", weight: 50, templateStyle: .standardCards),
        PaywallExperimentVariant(id: "timeline", weight: 50, templateStyle: .trialTimeline, headline: "Try 7 Days Free")
    ],
    holdoutPercentage: 0.10
)

@MainActor
struct AppRootView: View {
    @StateObject private var viewModel = PaywallViewModel(
        coordinator: EntitlementCoordinator(
            client: StoreKitClient(tierMapping: ["app.pro.yearly": .pro]),
            cache: KeychainEntitlementCache()
        ),
        productIDs: ["app.pro.monthly", "app.pro.yearly"],
        experiment: experiment,
        userID: "user-12345"
    )

    var body: some View {
        ProWorkspaceView()
            .requiresEntitlement(viewModel.entitlement, tier: .pro) {
                PaywallView(viewModel: viewModel)
            }
    }
}
```

## Running Tests

```bash
swift test
```

## License

MIT — see [LICENSE](./LICENSE).
