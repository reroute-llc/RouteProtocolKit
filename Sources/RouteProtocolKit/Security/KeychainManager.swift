import Foundation
import Security

/// Keychain manager for credentials and references (preserving existing patterns)
public actor KeychainManager {
    public static let defaultService = "com.reroute.encryption"
    
    // MARK: - Save
    
    /// Save credential to Keychain
    public static func save(
        _ value: Data,
        forKey key: String,
        service: String = defaultService
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String: value
        ]
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw RouteProtocolError.keychainSaveFailed(status)
        }
    }
    
    /// Save string to Keychain
    public static func save(
        _ value: String,
        forKey key: String,
        service: String = defaultService
    ) throws {
        guard let data = value.data(using: .utf8) else {
            throw RouteProtocolError.invalidParameter("value")
        }
        try save(data, forKey: key, service: service)
    }
    
    // MARK: - Load
    
    /// Load credential from Keychain
    public static func load(
        forKey key: String,
        service: String = defaultService
    ) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw RouteProtocolError.keychainLoadFailed(status)
        }
        
        return result as? Data
    }
    
    /// Load string from Keychain
    public static func loadString(
        forKey key: String,
        service: String = defaultService
    ) throws -> String? {
        guard let data = try load(forKey: key, service: service) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Delete
    
    /// Delete credential from Keychain
    public static func delete(
        forKey key: String,
        service: String = defaultService
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RouteProtocolError.keychainDeleteFailed(status)
        }
    }
    
    // MARK: - Exists
    
    /// Check if key exists in Keychain
    public static func exists(
        forKey key: String,
        service: String = defaultService
    ) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Update
    
    /// Update existing credential in Keychain
    public static func update(
        _ value: Data,
        forKey key: String,
        service: String = defaultService
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: value
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            // If item doesn't exist, create it
            if status == errSecItemNotFound {
                try save(value, forKey: key, service: service)
                return
            }
            throw RouteProtocolError.keychainSaveFailed(status)
        }
    }
    
    // MARK: - Clear All
    
    /// Clear all items for a service (use with caution!)
    public static func clearAll(service: String = defaultService) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RouteProtocolError.keychainDeleteFailed(status)
        }
    }
}

// MARK: - Convenience Extensions

extension KeychainManager {
    /// Save route token
    public static func saveRouteToken(
        _ token: String,
        routeID: String
    ) throws {
        try save(token, forKey: "route_token_\(routeID)")
    }
    
    /// Load route token
    public static func loadRouteToken(routeID: String) throws -> String? {
        try loadString(forKey: "route_token_\(routeID)")
    }
    
    /// Delete route token
    public static func deleteRouteToken(routeID: String) throws {
        try delete(forKey: "route_token_\(routeID)")
    }
    
    /// Save installation salt
    public static func saveInstallationSalt(_ salt: Data) throws {
        try save(salt, forKey: "installation_salt")
    }
    
    /// Load installation salt
    public static func loadInstallationSalt() throws -> Data? {
        try load(forKey: "installation_salt")
    }
    
    /// Get or create installation salt
    public static func getOrCreateInstallationSalt() throws -> Data {
        if let existing = try loadInstallationSalt() {
            return existing
        }
        
        let newSalt = SecurityManager.generateRandomData(count: 32)
        try saveInstallationSalt(newSalt)
        return newSalt
    }
}
