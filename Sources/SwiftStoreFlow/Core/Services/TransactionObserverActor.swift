import Foundation

/// Event published whenever the background transaction observer detects an entitlement change.
public struct EntitlementUpdateEvent: Equatable, Sendable {
    public let state: EntitlementState
    public let renewalState: RenewalState
    public let source: UpdateSource

    public enum UpdateSource: String, Sendable, Equatable {
        case transactionStream
        case receiptValidation
        case manualRefresh
    }

    public init(state: EntitlementState, renewalState: RenewalState, source: UpdateSource) {
        self.state = state
        self.renewalState = renewalState
        self.source = source
    }
}

/// Protocol providing an async stream of raw transaction snapshots (StoreKit 2 Transaction.updates or test stream).
public protocol TransactionStreamProviderProtocol: Sendable {
    func updates() -> AsyncStream<SubscriptionReceiptSnapshot>
}

/// Actor coordinating long-lived StoreKit transaction observation, JWS validation, and cache synchronization.
public actor TransactionObserverActor {
    private let validator: any ReceiptValidatorProtocol
    private let cache: any EntitlementCacheProtocol
    private let offlinePolicy: OfflineValidationPolicy

    private var observationTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<EntitlementUpdateEvent>.Continuation] = [:]
    private var latestEvent: EntitlementUpdateEvent?

    public init(
        validator: any ReceiptValidatorProtocol = LocalStoreKitReceiptValidator(),
        cache: any EntitlementCacheProtocol = KeychainEntitlementCache(),
        offlinePolicy: OfflineValidationPolicy = .allowCachedGraceWindow(seconds: 60 * 60 * 24 * 3)
    ) {
        self.validator = validator
        self.cache = cache
        self.offlinePolicy = offlinePolicy
    }

    public func currentLatestEvent() -> EntitlementUpdateEvent? {
        latestEvent
    }

    /// Subscribes to validated entitlement updates as a multi-consumer AsyncStream.
    public func entitlementStream() -> AsyncStream<EntitlementUpdateEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            if let existing = latestEvent {
                continuation.yield(existing)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    /// Starts observing an incoming transaction snapshot stream until stopped.
    public func startObserving(provider: any TransactionStreamProviderProtocol) {
        observationTask?.cancel()
        observationTask = Task {
            for await snapshot in provider.updates() {
                if Task.isCancelled { break }
                _ = await process(snapshot: snapshot, source: .transactionStream)
            }
        }
    }

    public func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    /// Processes a single receipt snapshot through JWS validation, offline fallback policy, and persistence.
    @discardableResult
    public func process(
        snapshot: SubscriptionReceiptSnapshot,
        source: EntitlementUpdateEvent.UpdateSource = .receiptValidation
    ) async -> EntitlementUpdateEvent {
        let decision: ValidationDecision
        do {
            decision = try await validator.validate(snapshot: snapshot)
        } catch {
            decision = .temporarilyUnavailable
        }

        let event: EntitlementUpdateEvent
        switch decision {
        case .valid(let verifiedState):
            try? await cache.save(verifiedState)
            event = EntitlementUpdateEvent(
                state: verifiedState,
                renewalState: snapshot.renewalState,
                source: source
            )
        case .rejected:
            try? await cache.clear()
            event = EntitlementUpdateEvent(
                state: .free,
                renewalState: snapshot.renewalState == .revoked ? .revoked : .expired,
                source: source
            )
        case .temporarilyUnavailable:
            event = await resolveOfflineFallback(for: snapshot, source: source)
        }

        latestEvent = event
        for continuation in continuations.values {
            continuation.yield(event)
        }
        return event
    }

    private func resolveOfflineFallback(
        for snapshot: SubscriptionReceiptSnapshot,
        source: EntitlementUpdateEvent.UpdateSource
    ) async -> EntitlementUpdateEvent {
        switch offlinePolicy {
        case .strictOnline:
            return EntitlementUpdateEvent(state: .free, renewalState: .expired, source: source)
        case .allowCachedGraceWindow(let allowedSeconds):
            if let cached = await cache.load(),
               Date().timeIntervalSince(cached.lastVerifiedAt) <= allowedSeconds,
               cached.isProActive {
                return EntitlementUpdateEvent(
                    state: cached,
                    renewalState: snapshot.renewalState,
                    source: source
                )
            }
            return EntitlementUpdateEvent(state: .free, renewalState: .expired, source: source)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
