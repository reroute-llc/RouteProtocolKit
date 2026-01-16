import Foundation
import CryptoKit
import Security

/// Security manager with Secure Enclave keys (preserving existing patterns)
public actor SecurityManager {
    // Secure Enclave keys (hardware-backed)
    private var identityKey: SecureEnclave.P256.Signing.PrivateKey?
    private var staticKeyAgreement: SecureEnclave.P256.KeyAgreement.PrivateKey?
    
    // Cached references (not actual keys) - actor-isolated
    private var keyCache: [String: Any] = [:]
    
    // MARK: - Initialization
    
    public init() {
        // Load keys lazily
    }
    
    // MARK: - Identity Keys (Signing)
    
    /// Get or create identity key in Secure Enclave
    public func getIdentityKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        if let existing = identityKey {
            return existing
        }
        
        // Try to load from Secure Enclave via Keychain reference
        if let loaded = try? loadIdentityKey() {
            identityKey = loaded
            return loaded
        }
        
        // Create new key in Secure Enclave
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        ) else {
            throw RouteProtocolError.keyCreationFailed
        }
        
        let newKey = try SecureEnclave.P256.Signing.PrivateKey(
            accessControl: accessControl
        )
        
        // Store key data representation in Keychain
        let keyData = newKey.dataRepresentation
        try KeychainManager.save(
            keyData,
            forKey: "identity_key_data",
            service: "com.reroute.encryption"
        )
        
        identityKey = newKey
        return newKey
    }
    
    private func loadIdentityKey() throws -> SecureEnclave.P256.Signing.PrivateKey? {
        guard let keyData = try KeychainManager.load(
            forKey: "identity_key_data",
            service: "com.reroute.encryption"
        ) else {
            return nil
        }
        
        return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
    }
    
    /// Get public identity key
    public func getPublicIdentityKey() throws -> P256.Signing.PublicKey {
        let privateKey = try getIdentityKey()
        return privateKey.publicKey
    }
    
    // MARK: - Key Agreement Keys
    
    /// Get or create static key agreement key in Secure Enclave
    public func getStaticKeyAgreementKey() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        if let existing = staticKeyAgreement {
            return existing
        }
        
        // Try to load from Secure Enclave via Keychain reference
        if let loaded = try? loadStaticKeyAgreementKey() {
            staticKeyAgreement = loaded
            return loaded
        }
        
        // Create new key in Secure Enclave
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        ) else {
            throw RouteProtocolError.keyCreationFailed
        }
        
        let newKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
            accessControl: accessControl
        )
        
        // Store key data representation in Keychain
        let keyData = newKey.dataRepresentation
        try KeychainManager.save(
            keyData,
            forKey: "static_key_agreement_data",
            service: "com.reroute.encryption"
        )
        
        staticKeyAgreement = newKey
        return newKey
    }
    
    private func loadStaticKeyAgreementKey() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey? {
        guard let keyData = try KeychainManager.load(
            forKey: "static_key_agreement_data",
            service: "com.reroute.encryption"
        ) else {
            return nil
        }
        
        return try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: keyData)
    }
    
    // MARK: - Ephemeral Keys (Per-Conversation)
    
    /// Create ephemeral key for conversation (Secure Enclave)
    public func createEphemeralKey(conversationID: String) throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        ) else {
            throw RouteProtocolError.keyCreationFailed
        }
        
        let ephemeralKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
            accessControl: accessControl
        )
        
        // Cache reference (not actual key) - actor-isolated, safe
        keyCache[conversationID] = ephemeralKey.publicKey.x963Representation
        
        return ephemeralKey
    }
    
    /// Get cached ephemeral key public representation
    public func getCachedEphemeralKeyData(conversationID: String) -> Data? {
        keyCache[conversationID] as? Data
    }
    
    /// Clear ephemeral key from cache
    public func clearEphemeralKey(conversationID: String) {
        keyCache.removeValue(forKey: conversationID)
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt data using ChaCha20-Poly1305
    public func encrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try ChaChaPoly.seal(data, using: key)
            return sealedBox.combined
        } catch {
            throw RouteProtocolError.encryptionFailed
        }
    }
    
    /// Decrypt data using ChaCha20-Poly1305
    public func decrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try ChaChaPoly.SealedBox(combined: data)
            return try ChaChaPoly.open(sealedBox, using: key)
        } catch {
            throw RouteProtocolError.decryptionFailed
        }
    }
    
    /// Derive symmetric key from shared secret
    public func deriveSymmetricKey(
        sharedSecret: SharedSecret,
        salt: Data? = nil,
        info: Data? = nil
    ) -> SymmetricKey {
        sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt ?? Data(),
            sharedInfo: info ?? Data(),
            outputByteCount: 32
        )
    }
    
    // MARK: - Signing
    
    /// Sign data with identity key
    public func sign(_ data: Data) throws -> Data {
        let privateKey = try getIdentityKey()
        let signature = try privateKey.signature(for: data)
        return signature.rawRepresentation
    }
    
    /// Verify signature with public key
    public func verify(
        signature: Data,
        for data: Data,
        publicKey: P256.Signing.PublicKey
    ) throws -> Bool {
        let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        return publicKey.isValidSignature(ecdsaSignature, for: data)
    }
    
    // MARK: - Random Data
    
    /// Generate cryptographically secure random data
    public nonisolated static func generateRandomData(count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        return data
    }
    
    // MARK: - Device Check
    
    /// Check if Secure Enclave is available
    public nonisolated static func isSecureEnclaveAvailable() -> Bool {
        SecureEnclave.isAvailable
    }
}
