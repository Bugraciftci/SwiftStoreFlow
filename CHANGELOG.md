# Changelog

All notable changes to `SwiftStoreFlow` are documented in this file.

## [2.0.0] - 2026-11-27

### Added
- Deterministic A/B paywall experimentation (`ExperimentBucketer`, 64-bit FNV-1a bucketing, holdout cohorts, QA overrides, and Chi-Square SRM guard).
- Churn recovery & win-back offer engine (`WinbackOfferEngine`) and SwiftUI analytics inspector (`PaywallAnalyticsInspectorView`).
- Live `TransactionObserverActor` with `AsyncStream<EntitlementUpdateEvent>` and `ReceiptValidatorProtocol` JWS verification hooks.
- 3 adaptive SwiftUI paywall templates (`StandardCards`, `TrialTimelineView`, `FeatureComparisonMatrixView`).
- High-contention purchase deduplication stress tests and 10k-iteration bucketer throughput benchmarks.
- GitHub Actions CI (`macos-15`), Swift DocC static documentation deployment, and `.spi.yml` for Swift Package Index.
