import Foundation

/// Route protocol - Swift protocol for route implementations
///
/// This protocol defines the interface that all routes must implement.
/// It uses modern Swift concurrency (async/await) and is Sendable for thread-safety.
public protocol RouteProtocol: Sendable {
    // MARK: - Route Identity
    
    /// Unique route ID
    var routeID: String { get async }
    
    /// Platform identifier (e.g., "discord", "whatsapp", "telegram")
    var platform: String { get }
    
    /// Display name for UI
    var displayName: String { get async }
    
    // MARK: - Authentication
    
    /// Authenticate with the route
    /// - Returns: Authentication data (e.g., token, session ID)
    func authenticate() async throws -> [String: String]
    
    /// Check if route has valid authentication
    func isAuthenticated() async -> Bool
    
    /// Sign out from the route
    func signOut() async throws
    
    // MARK: - Connection Management
    
    /// Connect to the route
    func connect() async throws
    
    /// Disconnect from the route
    func disconnect() async throws
    
    /// Check if route is connected
    func isConnected() async -> Bool
    
    // MARK: - Messaging
    
    /// Send a text message
    /// - Parameters:
    ///   - conversationID: Conversation identifier
    ///   - text: Message text
    ///   - replyToMessageID: Optional message ID to reply to
    /// - Returns: Sent message
    func sendMessage(
        conversationID: String,
        text: String,
        replyToMessageID: String?
    ) async throws -> Message
    
    /// Send a media message
    /// - Parameters:
    ///   - conversationID: Conversation identifier
    ///   - mediaData: Media file data
    ///   - mediaType: Type of media (image, video, audio, file)
    ///   - caption: Optional caption
    /// - Returns: Sent message
    func sendMediaMessage(
        conversationID: String,
        mediaData: Data,
        mediaType: MessageContentType,
        caption: String?
    ) async throws -> Message
    
    /// Delete a message
    /// - Parameter messageID: Message identifier
    func deleteMessage(messageID: String) async throws
    
    /// Edit a message
    /// - Parameters:
    ///   - messageID: Message identifier
    ///   - newText: New message text
    func editMessage(messageID: String, newText: String) async throws
    
    /// React to a message
    /// - Parameters:
    ///   - messageID: Message identifier
    ///   - emoji: Reaction emoji
    func addReaction(messageID: String, emoji: String) async throws
    
    /// Remove reaction from a message
    /// - Parameters:
    ///   - messageID: Message identifier
    ///   - emoji: Reaction emoji
    func removeReaction(messageID: String, emoji: String) async throws
    
    // MARK: - Conversations
    
    /// Get all conversations
    func getConversations() async throws -> [Conversation]
    
    /// Get conversation by ID
    func getConversation(id: String) async throws -> Conversation
    
    /// Create a new conversation (if supported)
    func createConversation(
        participantIDs: [String],
        name: String?
    ) async throws -> Conversation
    
    /// Load older messages in a conversation
    /// - Parameters:
    ///   - conversationID: Conversation identifier
    ///   - beforeMessageID: Load messages before this message
    ///   - limit: Maximum number of messages to load
    /// - Returns: Array of messages
    func loadOlderMessages(
        conversationID: String,
        beforeMessageID: String?,
        limit: Int
    ) async throws -> [Message]
    
    // MARK: - Typing Indicators
    
    /// Send typing indicator
    func sendTypingIndicator(conversationID: String) async throws
    
    // MARK: - Voice/Video Calls
    
    /// Start voice call
    /// - Parameter conversationID: Conversation identifier
    /// - Returns: Call metadata
    func startVoiceCall(conversationID: String) async throws -> [String: String]
    
    /// Start video call
    /// - Parameter conversationID: Conversation identifier
    /// - Returns: Call metadata
    func startVideoCall(conversationID: String) async throws -> [String: String]
    
    /// End call
    func endCall() async throws
    
    // MARK: - History Sync
    
    /// Get history sync mode
    func getHistorySyncMode() async -> HistorySyncMode
    
    /// Perform full history sync (if supported)
    func syncFullHistory() async throws
    
    // MARK: - Metadata & Configuration
    
    /// Get route metadata
    func getMetadata() async -> [String: String]
    
    /// Update route metadata
    func updateMetadata(_ metadata: [String: String]) async throws
}

// MARK: - History Sync Mode

/// History synchronization mode
public enum HistorySyncMode: String, Codable, Sendable {
    /// No automatic history sync
    case none
    
    /// On-demand history sync (load older messages when requested)
    case onDemand
    
    /// Full history sync (sync all messages on connect)
    case full
}

// MARK: - Protocol Extensions (Default Implementations)

extension RouteProtocol {
    /// Default implementation: no full history sync
    public func syncFullHistory() async throws {
        // Default: do nothing
    }
    
    /// Default implementation: on-demand sync
    public func getHistorySyncMode() async -> HistorySyncMode {
        .onDemand
    }
    
    /// Default implementation: empty metadata
    public func getMetadata() async -> [String: String] {
        [:]
    }
    
    /// Default implementation: no-op update
    public func updateMetadata(_ metadata: [String: String]) async throws {
        // Default: do nothing
    }
    
    /// Default implementation: no-op typing indicator
    public func sendTypingIndicator(conversationID: String) async throws {
        // Default: do nothing
    }
    
    /// Default implementation: throw not supported
    public func createConversation(
        participantIDs: [String],
        name: String?
    ) async throws -> Conversation {
        throw RouteProtocolError.invalidRouteConfiguration
    }
}
