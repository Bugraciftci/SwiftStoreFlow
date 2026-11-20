import Foundation
import Security

/// Keychain-backed actor cache storing signed entitlement snapshots securely on device.
public actor KeychainEntitlementCache: EntitlementCacheProtocol {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        service: String = "com.bugraciftci.swiftstoreflow.entitlements",
        account: String = "current_entitlement"
    ) {
        self.service = service
        self.account = account
    }

    public func load() async -> EntitlementState? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? decoder.decode(EntitlementState.self, from: data)
    }

    public func save(_ state: EntitlementState) async throws {
        let data: Data
        do {
            data = try encoder.encode(state)
        } catch {
            throw StoreFlowError.persistenceFailure(error.localizedDescription)
        }

        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertQuery = baseQuery
            insertQuery[kSecValueData] = data
            insertQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw StoreFlowError.persistenceFailure("Keychain insert failed with OSStatus \(addStatus)")
            }
        } else if updateStatus != errSecSuccess {
            throw StoreFlowError.persistenceFailure("Keychain update failed with OSStatus \(updateStatus)")
        }
    }

    public func clear() async throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreFlowError.persistenceFailure("Keychain delete failed with OSStatus \(status)")
        }
    }
}
