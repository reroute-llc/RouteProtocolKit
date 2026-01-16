import Foundation
import GRDB
import CryptoKit

/// Route Protocol SDK - Swift modern implementation
///
/// Main entry point for the Route Protocol SDK. Provides a unified interface
/// for managing routes, messages, conversations, and events.
public actor RouteProtocolSDK {
    // MARK: - Components
    
    /// Storage manager (GRDB)
    public let storage: StorageManager
    
    /// Security manager (Secure Enclave + Keychain)
    public let security: SecurityManager
    
    /// State manager (Actor-based)
    public let stateManager: RouteStateManager
    
    /// Event queue manager (Actor-based)
    public let eventQueue: EventQueueManager
    
    /// Reconnection manager (Actor-based)
    public let reconnection: ReconnectionManager
    
    /// Retry manager (Actor-based)
    public let retry: RetryManager
    
    // MARK: - Route Registry
    
    private var routes: [String: any RouteProtocol] = [:]
    
    // MARK: - Initialization
    
    /// Initialize the SDK
    /// - Parameters:
    ///   - storagePath: Path to database file
    ///   - passphrase: Optional passphrase for SQLCipher encryption
    public init(storagePath: String, passphrase: String? = nil) async throws {
        // Initialize storage with GRDB
        self.storage = try StorageManager(path: storagePath, passphrase: passphrase)
        
        // Initialize security with Secure Enclave
        self.security = SecurityManager()
        
        // Initialize state management
        self.stateManager = RouteStateManager()
        
        // Initialize event queue (actor-based)
        self.eventQueue = EventQueueManager(storage: storage)
        
        // Initialize reconnection manager
        self.reconnection = ReconnectionManager()
        
        // Initialize retry manager
        self.retry = RetryManager()
        
        // Load queued events from database
        try await eventQueue.loadFromDatabase()
        
        // Register event processing callback
        await eventQueue.registerProcessingCallback { [weak self] event in
            guard self != nil else { return }
            // Process event through registered routes
            // This would be implemented by the specific route
        }
    }
    
    // MARK: - Route Management
    
    /// Register a route
    public func registerRoute(_ route: any RouteProtocol) async throws {
        let routeID = await route.routeID
        routes[routeID] = route
        
        // Initialize state
        await stateManager.setState(routeID: routeID, state: .disconnected)
        
        // Save to database
        let platform = await route.platform
        let displayName = await route.displayName
        
        let routeModel = Route(
            id: routeID,
            platform: platform,
            displayName: displayName,
            state: .disconnected
        )
        
        try await storage.write { db in
            try routeModel.insert(db)
        }
    }
    
    /// Unregister a route
    public func unregisterRoute(routeID: String) async throws {
        routes.removeValue(forKey: routeID)
        
        // Clear state
        await stateManager.clearState(routeID: routeID)
        
        // Clear events
        try await eventQueue.clearEvents(for: routeID)
        
        // Delete from database
        try await storage.write { db in
            try db.execute(
                sql: "DELETE FROM routes WHERE id = ?",
                arguments: [routeID]
            )
        }
    }
    
    /// Get route by ID
    public func getRoute(routeID: String) -> (any RouteProtocol)? {
        routes[routeID]
    }
    
    /// Get all registered routes
    public func getAllRoutes() -> [any RouteProtocol] {
        Array(routes.values)
    }
    
    // MARK: - Connection Management
    
    /// Connect a route
    public func connectRoute(routeID: String) async throws {
        guard let route = routes[routeID] else {
            throw RouteProtocolError.routeNotFound(routeID)
        }
        
        // Set state to connecting
        await stateManager.setState(routeID: routeID, state: .connecting)
        
        do {
            // Execute with retry
            try await retry.executeWithRetry(
                operationID: "connect_\(routeID)",
                policy: .default
            ) {
                try await route.connect()
            }
            
            // Set state to connected
            await stateManager.setState(routeID: routeID, state: .connected)
            
            // Process queued events
            _ = try await eventQueue.processEvents(for: routeID)
            
            // Reset reconnection state
            await reconnection.reset(routeID: routeID)
            
        } catch {
            await stateManager.setError(routeID: routeID, error: error.localizedDescription)
            
            // Trigger reconnection if enabled
            if await reconnection.canReconnect(routeID: routeID) {
                try await scheduleReconnection(routeID: routeID)
            }
            
            throw error
        }
    }
    
    /// Disconnect a route
    public func disconnectRoute(routeID: String) async throws {
        guard let route = routes[routeID] else {
            throw RouteProtocolError.routeNotFound(routeID)
        }
        
        // Set state to disconnecting
        await stateManager.setState(routeID: routeID, state: .disconnecting)
        
        // Disconnect
        try await route.disconnect()
        
        // Set state to disconnected
        await stateManager.setState(routeID: routeID, state: .disconnected)
        
        // Reset reconnection state
        await reconnection.reset(routeID: routeID)
    }
    
    // MARK: - Reconnection
    
    private func scheduleReconnection(routeID: String) async throws {
        await stateManager.setState(routeID: routeID, state: .reconnecting)
        
        let delay = try await reconnection.triggerReconnection(routeID: routeID)
        
        // Schedule reconnection after delay
        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                try await self.connectRoute(routeID: routeID)
                await self.reconnection.completeReconnection(routeID: routeID, success: true)
            } catch {
                await self.reconnection.completeReconnection(routeID: routeID, success: false)
                
                // Try again if possible
                if await self.reconnection.canReconnect(routeID: routeID) {
                    try await self.scheduleReconnection(routeID: routeID)
                }
            }
        }
    }
    
    // MARK: - Messaging
    
    /// Send a message
    public func sendMessage(
        routeID: String,
        conversationID: String,
        text: String,
        replyToMessageID: String? = nil
    ) async throws -> Message {
        guard let route = routes[routeID] else {
            throw RouteProtocolError.routeNotFound(routeID)
        }
        
        guard await stateManager.isConnected(routeID: routeID) else {
            throw RouteProtocolError.routeNotConnected
        }
        
        // Send via route with retry
        return try await retry.executeWithRetry(
            operationID: "send_message_\(routeID)_\(UUID().uuidString)",
            policy: .default
        ) {
            try await route.sendMessage(
                conversationID: conversationID,
                text: text,
                replyToMessageID: replyToMessageID
            )
        }
    }
    
    /// Load older messages
    public func loadOlderMessages(
        routeID: String,
        conversationID: String,
        beforeMessageID: String? = nil,
        limit: Int = 50
    ) async throws -> [Message] {
        guard let route = routes[routeID] else {
            throw RouteProtocolError.routeNotFound(routeID)
        }
        
        guard await stateManager.isConnected(routeID: routeID) else {
            throw RouteProtocolError.routeNotConnected
        }
        
        return try await route.loadOlderMessages(
            conversationID: conversationID,
            beforeMessageID: beforeMessageID,
            limit: limit
        )
    }
    
    // MARK: - Storage Operations
    
    /// Get all conversations
    public func getConversations() async throws -> [Conversation] {
        try await storage.read { db in
            try Conversation.fetchAll(db)
        }
    }
    
    /// Get conversations for a specific route
    public func getConversations(routeID: String) async throws -> [Conversation] {
        try await storage.read { db in
            try Conversation
                .filter(Column("routeID") == routeID)
                .order(Column("lastMessageTimestamp").desc)
                .fetchAll(db)
        }
    }
    
    /// Get messages for a conversation
    public func getMessages(conversationID: String, limit: Int = 100) async throws -> [Message] {
        try await storage.read { db in
            try Message
                .filter(Column("conversationID") == conversationID)
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    // MARK: - Event Queue Operations
    
    /// Queue an event
    public func queueEvent(_ event: Event) async throws {
        try await eventQueue.enqueue(event)
    }
    
    /// Process queued events for a route
    public func processQueuedEvents(routeID: String) async throws -> Int {
        try await eventQueue.processEvents(for: routeID)
    }
    
    /// Get queue size for a route
    public func getQueueSize(routeID: String) async -> Int {
        await eventQueue.getQueueSize(for: routeID)
    }
    
    // MARK: - State Operations
    
    /// Get route state
    public func getRouteState(routeID: String) async -> RouteState {
        await stateManager.getState(routeID: routeID)
    }
    
    /// Check if route is connected
    public func isRouteConnected(routeID: String) async -> Bool {
        await stateManager.isConnected(routeID: routeID)
    }
    
    // MARK: - Cleanup
    
    /// Cleanup old events and optimize database
    public func cleanup() async throws {
        // Delete events older than 7 days
        try await eventQueue.cleanupOldEvents(olderThan: 7 * 24 * 60 * 60)
        
        // Vacuum database
        try await storage.vacuum()
    }
    
    /// Close SDK and cleanup resources
    public func close() async throws {
        try await storage.close()
    }
}

// MARK: - Public API Convenience

extension RouteProtocolSDK {
    /// Create SDK with default configuration
    public static func create(
        storagePath: String? = nil
    ) async throws -> RouteProtocolSDK {
        let path = storagePath ?? Self.defaultStoragePath()
        return try await RouteProtocolSDK(storagePath: path)
    }
    
    /// Get default storage path
    public static func defaultStoragePath() -> String {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return documentsPath.appendingPathComponent("route_protocol.db").path
    }
}
