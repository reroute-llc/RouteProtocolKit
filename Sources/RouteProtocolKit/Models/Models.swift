import Foundation

// MARK: - Route Models

/// Route state
public enum RouteState: String, Codable, Sendable {
    case disconnected = "DISCONNECTED"
    case connecting = "CONNECTING"
    case connected = "CONNECTED"
    case reconnecting = "RECONNECTING"
    case disconnecting = "DISCONNECTING"
    case error = "ERROR"
}

/// Route information
public struct Route: Codable, Sendable {
    public let id: String
    public let platform: String
    public let displayName: String
    public let state: RouteState
    public let metadata: [String: String]
    public let createdAt: Date
    public let lastConnectedAt: Date?
    
    public init(
        id: String,
        platform: String,
        displayName: String,
        state: RouteState,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.platform = platform
        self.displayName = displayName
        self.state = state
        self.metadata = metadata
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
    }
}

// MARK: - Message Models

/// Message content type
public enum MessageContentType: String, Codable, Sendable {
    case text
    case image
    case video
    case audio
    case file
    case location
    case contact
    case sticker
}

/// Message status
public enum MessageStatus: String, Codable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

/// Message
public struct Message: Codable, Sendable, Identifiable {
    public let id: String
    public let conversationID: String
    public let senderID: String
    public let contentType: MessageContentType
    public let text: String?
    public let timestamp: Date
    public let status: MessageStatus
    public let replyToMessageID: String?
    public let replyToPreview: String?
    public let platformMessageID: String?
    public let attachmentMetadata: [String: String]?
    
    public init(
        id: String,
        conversationID: String,
        senderID: String,
        contentType: MessageContentType,
        text: String? = nil,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        replyToMessageID: String? = nil,
        replyToPreview: String? = nil,
        platformMessageID: String? = nil,
        attachmentMetadata: [String: String]? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.contentType = contentType
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.replyToMessageID = replyToMessageID
        self.replyToPreview = replyToPreview
        self.platformMessageID = platformMessageID
        self.attachmentMetadata = attachmentMetadata
    }
}

// MARK: - Conversation Models

/// Conversation
public struct Conversation: Codable, Sendable, Identifiable {
    public let id: String
    public let routeID: String
    public let displayName: String
    public let avatarURL: String?
    public let lastMessageText: String?
    public let lastMessageTimestamp: Date?
    public let unreadCount: Int
    public let isGroup: Bool
    public let participantIDs: [String]
    public let metadata: [String: String]
    
    public init(
        id: String,
        routeID: String,
        displayName: String,
        avatarURL: String? = nil,
        lastMessageText: String? = nil,
        lastMessageTimestamp: Date? = nil,
        unreadCount: Int = 0,
        isGroup: Bool = false,
        participantIDs: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.routeID = routeID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.lastMessageText = lastMessageText
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
        self.isGroup = isGroup
        self.participantIDs = participantIDs
        self.metadata = metadata
    }
}

// MARK: - Event Models

/// Event type
public enum EventType: String, Codable, Sendable {
    case messageReceived = "MESSAGE_RECEIVED"
    case reactionAdded = "REACTION_ADDED"
    case reactionRemoved = "REACTION_REMOVED"
    case typingIndicator = "TYPING_INDICATOR"
    case messageDeleted = "MESSAGE_DELETED"
    case messageUpdated = "MESSAGE_UPDATED"
    case callStarted = "CALL_STARTED"
    case callEnded = "CALL_ENDED"
    case conversationCreated = "CONVERSATION_CREATED"
    case conversationUpdated = "CONVERSATION_UPDATED"
}

/// Event
public struct Event: Codable, Sendable, Identifiable {
    public let id: String
    public let routeID: String
    public let type: EventType
    public let timestamp: Date
    public let payload: Data
    
    public init(
        id: String = UUID().uuidString,
        routeID: String,
        type: EventType,
        timestamp: Date = Date(),
        payload: Data
    ) {
        self.id = id
        self.routeID = routeID
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
    }
}

// MARK: - Reconnection Config

/// Reconnection configuration
public struct ReconnectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let maxAttempts: Int
    public let initialDelaySeconds: Double
    public let maxDelaySeconds: Double
    public let backoffMultiplier: Double
    
    public init(
        enabled: Bool = true,
        maxAttempts: Int = 5,
        initialDelaySeconds: Double = 1.0,
        maxDelaySeconds: Double = 60.0,
        backoffMultiplier: Double = 2.0
    ) {
        self.enabled = enabled
        self.maxAttempts = maxAttempts
        self.initialDelaySeconds = initialDelaySeconds
        self.maxDelaySeconds = maxDelaySeconds
        self.backoffMultiplier = backoffMultiplier
    }
    
    public static let `default` = ReconnectionConfig()
}

// MARK: - Retry Policy

/// Retry policy
public struct RetryPolicy: Codable, Sendable {
    public let maxAttempts: Int
    public let initialDelaySeconds: Double
    public let maxDelaySeconds: Double
    public let backoffMultiplier: Double
    
    public init(
        maxAttempts: Int = 3,
        initialDelaySeconds: Double = 0.5,
        maxDelaySeconds: Double = 30.0,
        backoffMultiplier: Double = 2.0
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelaySeconds = initialDelaySeconds
        self.maxDelaySeconds = maxDelaySeconds
        self.backoffMultiplier = backoffMultiplier
    }
    
    public static let `default` = RetryPolicy()
    public static let aggressive = RetryPolicy(maxAttempts: 5, initialDelaySeconds: 0.1)
    public static let conservative = RetryPolicy(maxAttempts: 2, initialDelaySeconds: 1.0)
}
