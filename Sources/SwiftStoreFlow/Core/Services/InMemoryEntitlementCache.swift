import Foundation

/// Thread-safe actor-isolated in-memory entitlement cache for previews and unit tests.
public actor InMemoryEntitlementCache: EntitlementCacheProtocol {
    private var cachedState: EntitlementState?

    public init(initialState: EntitlementState? = nil) {
        self.cachedState = initialState
    }

    public func load() async -> EntitlementState? {
        cachedState
    }

    public func save(_ state: EntitlementState) async throws {
        cachedState = state
    }

    public func clear() async throws {
        cachedState = nil
    }
}
