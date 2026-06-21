import Foundation
import Security

/// Keychain-backed store for the root folder security-scoped bookmark.
///
/// Replaces the previous `UserDefaults` storage (SECURITY_AUDIT M2): the bookmark
/// blob encodes the resolved root folder and grants future access to it, so keeping
/// it in the preferences plist made it readable by any same-user process — especially
/// risky with the macOS App Sandbox disabled. The Keychain is access-controlled per app.
///
/// Uses `kSecClassGenericPassword`. On iOS this is always the data-protection keychain;
/// on macOS (non-sandboxed) it uses the file-based login keychain, which is sufficient
/// to keep the blob out of the world-readable prefs plist without requiring extra
/// keychain-access-group entitlements.
enum BookmarkStore {
    private static let account = "rootFolderBookmark"
    private static let service = "com.mab.Vera.bookmark"

    /// Returns the stored bookmark data, migrating any legacy `UserDefaults` value
    /// into the Keychain on first access so existing installs keep their folder.
    static func load() -> Data? {
        if let data = read() { return data }
        if let legacy = UserDefaults.standard.data(forKey: account) {
            save(legacy)
            UserDefaults.standard.removeObject(forKey: account)
            return legacy
        }
        return nil
    }

    static func save(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        // Clear any legacy value too, in case migration never ran.
        UserDefaults.standard.removeObject(forKey: account)
    }

    private static func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
