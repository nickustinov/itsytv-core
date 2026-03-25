import Foundation
import Security
import os.log

private let log = CoreLog(category: "Keychain")

/// Stores and retrieves HAP credentials in the system Keychain.
public enum KeychainStorage {

    private static let service = "com.itsytv.credentials"

    public static func save(credentials: HAPCredentials, for deviceID: String) throws {
        let data = try JSONEncoder().encode(credentials)

        // Delete existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public static func load(for deviceID: String) -> HAPCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess {
            log.error("load(\(deviceID)): SecItemCopyMatching failed with OSStatus \(status)")
        }
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        do {
            return try JSONDecoder().decode(HAPCredentials.self, from: data)
        } catch {
            log.error("Failed to decode credentials for \(deviceID): \(error.localizedDescription)")
            return nil
        }
    }

    public static func delete(for deviceID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
        ]
        SecItemDelete(query as CFDictionary)
    }

    public static func allPairedDeviceIDs() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess {
            log.error("allPairedDeviceIDs: SecItemCopyMatching failed with OSStatus \(status)")
        }
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        log.error("allPairedDeviceIDs: found \(items.count) items")

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    public enum KeychainError: Swift.Error {
        case saveFailed(OSStatus)
    }
}
