// RouteProtocolKit - Swift SDK for Route Protocol
//
// Modern Swift SDK replacing the C SDK, providing:
// - GRDB-based storage with iOS File Protection
// - Secure Enclave for cryptographic keys
// - Keychain for credentials
// - Actor-based concurrency
// - Event queuing and replay
// - Automatic reconnection
// - Retry logic

// Re-export all public APIs
@_exported import GRDB

// MARK: - Version

public struct RouteProtocolKitVersion {
    public static let major = 1
    public static let minor = 0
    public static let patch = 0
    
    public static var string: String {
        "\(major).\(minor).\(patch)"
    }
}
