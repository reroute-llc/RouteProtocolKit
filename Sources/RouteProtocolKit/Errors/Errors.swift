import Foundation

// MARK: - SDK Errors

/// Route Protocol Kit errors
public enum RouteProtocolError: Error, LocalizedError, Sendable {
    // Storage errors
    case databaseNotFound
    case databaseCorrupted
    case databaseReadFailed(Error)
    case databaseWriteFailed(Error)
    case migrationFailed(Error)
    
    // Security errors
    case secureEnclaveNotAvailable
    case keyCreationFailed
    case keyLoadFailed
    case encryptionFailed
    case decryptionFailed
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    
    // State errors
    case invalidState(current: String, required: String)
    case routeNotFound(String)
    case conversationNotFound(String)
    case messageNotFound(String)
    
    // Event errors
    case eventQueueFull
    case eventProcessingFailed(Error)
    case invalidEventPayload
    
    // Reconnection errors
    case reconnectionDisabled
    case maxReconnectionAttemptsReached
    case reconnectionInProgress
    
    // Retry errors
    case maxRetryAttemptsReached
    case operationTimedOut
    
    // Route errors
    case routeNotConnected
    case routeAuthenticationFailed(Error)
    case routeOperationFailed(Error)
    case invalidRouteConfiguration
    
    // Network errors
    case networkUnavailable
    case requestFailed(Error)
    
    // Generic errors
    case invalidParameter(String)
    case operationCancelled
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        // Storage
        case .databaseNotFound:
            return "Database not found"
        case .databaseCorrupted:
            return "Database is corrupted"
        case .databaseReadFailed(let error):
            return "Failed to read from database: \(error.localizedDescription)"
        case .databaseWriteFailed(let error):
            return "Failed to write to database: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Database migration failed: \(error.localizedDescription)"
            
        // Security
        case .secureEnclaveNotAvailable:
            return "Secure Enclave is not available on this device"
        case .keyCreationFailed:
            return "Failed to create cryptographic key"
        case .keyLoadFailed:
            return "Failed to load cryptographic key"
        case .encryptionFailed:
            return "Encryption operation failed"
        case .decryptionFailed:
            return "Decryption operation failed"
        case .keychainSaveFailed(let status):
            return "Keychain save failed with status: \(status)"
        case .keychainLoadFailed(let status):
            return "Keychain load failed with status: \(status)"
        case .keychainDeleteFailed(let status):
            return "Keychain delete failed with status: \(status)"
            
        // State
        case .invalidState(let current, let required):
            return "Invalid state: current=\(current), required=\(required)"
        case .routeNotFound(let id):
            return "Route not found: \(id)"
        case .conversationNotFound(let id):
            return "Conversation not found: \(id)"
        case .messageNotFound(let id):
            return "Message not found: \(id)"
            
        // Events
        case .eventQueueFull:
            return "Event queue is full"
        case .eventProcessingFailed(let error):
            return "Event processing failed: \(error.localizedDescription)"
        case .invalidEventPayload:
            return "Invalid event payload"
            
        // Reconnection
        case .reconnectionDisabled:
            return "Reconnection is disabled"
        case .maxReconnectionAttemptsReached:
            return "Maximum reconnection attempts reached"
        case .reconnectionInProgress:
            return "Reconnection already in progress"
            
        // Retry
        case .maxRetryAttemptsReached:
            return "Maximum retry attempts reached"
        case .operationTimedOut:
            return "Operation timed out"
            
        // Route
        case .routeNotConnected:
            return "Route is not connected"
        case .routeAuthenticationFailed(let error):
            return "Route authentication failed: \(error.localizedDescription)"
        case .routeOperationFailed(let error):
            return "Route operation failed: \(error.localizedDescription)"
        case .invalidRouteConfiguration:
            return "Invalid route configuration"
            
        // Network
        case .networkUnavailable:
            return "Network is unavailable"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
            
        // Generic
        case .invalidParameter(let param):
            return "Invalid parameter: \(param)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
