# SwiftStoreFlow

[![Swift 6](https://img.shields.io/badge/Swift_6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/iOS_17%2B_%7C_macOS_14%2B-0071E3?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](./LICENSE)

Production-grade **Swift 6 & SwiftUI StoreKit 2** monetization and entitlement architecture extracted from commercial App Store apps. Built with strict concurrency (`Sendable`, `actor`, `async/await`), protocol-oriented MVVM, Keychain-backed offline fallback, and deterministic `XCTest` coverage.

## Architecture

```mermaid
flowchart LR
    V[SwiftUI PaywallView<br/>& EntitlementGateModifier] --> VM["@MainActor PaywallViewModel<br/>(@Published State Machine)"]
    VM --> C["actor EntitlementCoordinator<br/>(Deduplication & Offline Fallback)"]
    C --> SK[StoreClientProtocol<br/>StoreKit 2 / MockStoreClient]
    C --> KC[EntitlementCacheProtocol<br/>Keychain / InMemory Actor]
    C --> AN[PaywallAnalyticsProtocol<br/>Funnel Events]
```

## Key Engineering Highlights

- **Strict Swift 6 Concurrency:** Full `Sendable` value types, `actor`-isolated `EntitlementCoordinator`, and `@MainActor` MVVM state management with zero data races.
- **Re-Entrancy Protection:** Guards against double-tap purchase races with deterministic `.purchaseInProgress` rejection.
- **Offline-First Keychain Entitlements:** Encrypted device-only `KeychainEntitlementCache` (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) ensures paying users retain access offline.
- **Protocol-Oriented Testability:** Every StoreKit 2, Keychain, and analytics boundary is protocol-abstracted for fast, sandbox-free `swift test` execution.
- **Adaptive SwiftUI Components:** `PaywallView`, `PlanOptionCard`, and `.requiresEntitlement(...)` supporting Dark Mode, Dynamic Type, SF Symbols, and VoiceOver.

## Quick Usage

```swift
import SwiftUI
import SwiftStoreFlow

struct AppRootView: View {
    @StateObject private var viewModel = PaywallViewModel(
        coordinator: EntitlementCoordinator(
            client: StoreKitClient(tierMapping: ["app.pro.yearly": .pro]),
            cache: KeychainEntitlementCache()
        ),
        productIDs: ["app.pro.monthly", "app.pro.yearly"],
        placement: "onboarding"
    )

    var body: some View {
        ProWorkspaceView()
            .requiresEntitlement(viewModel.entitlement, tier: .pro) {
                PaywallView(viewModel: viewModel)
            }
    }
}
```

## Installation (Swift Package Manager)

```swift
dependencies: [
    .package(url: "https://github.com/Bugraciftci/SwiftStoreFlow.git", from: "1.0.0")
]
```

## Running Tests

```bash
swift test
```

## License

MIT — see [LICENSE](./LICENSE).
