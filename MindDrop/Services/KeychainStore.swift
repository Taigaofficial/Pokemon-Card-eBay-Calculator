import Foundation
import Security
import SwiftUI

/// Minimal Keychain wrapper for the API keys. Values are stored as generic
/// passwords scoped to this app, so they never leave the device unencrypted
/// (unlike UserDefaults, which is written to a plain plist).
enum KeychainStore {
    private static let service = "com.minddrop.app"

    static func string(for key: String) -> String? {
        // One-time migration: earlier builds kept keys in UserDefaults.
        if let legacy = UserDefaults.standard.string(forKey: key), !legacy.isEmpty {
            set(legacy, for: key)
            UserDefaults.standard.removeObject(forKey: key)
            return legacy
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String?, for key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        guard let value, !value.isEmpty else {
            SecItemDelete(base as CFDictionary)
            return
        }

        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// SwiftUI property wrapper mirroring `@AppStorage`, but backed by the
/// Keychain. Use for secrets only.
@propertyWrapper
struct KeychainStorage: DynamicProperty {
    @State private var value: String
    private let key: String

    init(wrappedValue defaultValue: String = "", _ key: String) {
        self.key = key
        _value = State(initialValue: KeychainStore.string(for: key) ?? defaultValue)
    }

    var wrappedValue: String {
        get { value }
        nonmutating set {
            value = newValue
            KeychainStore.set(newValue, for: key)
        }
    }

    var projectedValue: Binding<String> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
