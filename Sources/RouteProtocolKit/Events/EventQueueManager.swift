import Foundation

/// Event queue manager (Actor-based, thread-safe)
public actor EventQueueManager {
    // MARK: - Configuration
    
    private let maxQueueSize: Int
    private let storage: StorageManager
    
    // MARK: - State
    
    private var inMemoryQueue: [Event] = []
    private var processingCallbacks: [(Event) async throws -> Void] = []
    
    // MARK: - Initialization
    
    public init(
        storage: StorageManager,
        maxQueueSize: Int = 1000
    ) {
        self.storage = storage
        self.maxQueueSize = maxQueueSize
    }
    
    // MARK: - Queue Operations
    
    /// Enqueue an event
    public func enqueue(_ event: Event) async throws {
        // Check queue size
        guard inMemoryQueue.count < maxQueueSize else {
            throw RouteProtocolError.eventQueueFull
        }
        
        // Add to in-memory queue
        inMemoryQueue.append(event)
        
        // Persist to database
        try await storage.write { db in
            var mutableEvent = event
            try mutableEvent.insert(db)
        }
    }
    
    /// Dequeue and process all events for a route
    public func processEvents(
        for routeID: String
    ) async throws -> Int {
        // Get events from in-memory queue
        let events = inMemoryQueue.filter { $0.routeID == routeID }
        
        var processedCount = 0
        
        for event in events {
            do {
                // Call processing callbacks
                for callback in processingCallbacks {
                    try await callback(event)
                }
                
                // Remove from in-memory queue
                inMemoryQueue.removeAll { $0.id == event.id }
                
                // Mark as processed in database
                try await storage.write { db in
                    try db.execute(
                        sql: """
                        UPDATE events
                        SET processed = 1
                        WHERE id = ?
                        """,
                        arguments: [event.id]
                    )
                }
                
                processedCount += 1
            } catch {
                // Log error but continue processing other events
                print("Failed to process event \(event.id): \(error)")
            }
        }
        
        return processedCount
    }
    
    /// Process all queued events (across all routes)
    public func processAllEvents() async throws -> Int {
        var processedCount = 0
        
        for event in inMemoryQueue {
            do {
                // Call processing callbacks
                for callback in processingCallbacks {
                    try await callback(event)
                }
                
                // Mark as processed in database
                try await storage.write { db in
                    try db.execute(
                        sql: """
                        UPDATE events
                        SET processed = 1
                        WHERE id = ?
                        """,
                        arguments: [event.id]
                    )
                }
                
                processedCount += 1
            } catch {
                // Log error but continue processing other events
                print("Failed to process event \(event.id): \(error)")
            }
        }
        
        // Clear in-memory queue
        inMemoryQueue.removeAll()
        
        return processedCount
    }
    
    /// Clear all events for a route
    public func clearEvents(for routeID: String) async throws {
        // Remove from in-memory queue
        inMemoryQueue.removeAll { $0.routeID == routeID }
        
        // Delete from database
        try await storage.write { db in
            try db.execute(
                sql: """
                DELETE FROM events
                WHERE routeID = ?
                """,
                arguments: [routeID]
            )
        }
    }
    
    /// Get queue size for a route
    public func getQueueSize(for routeID: String) -> Int {
        inMemoryQueue.filter { $0.routeID == routeID }.count
    }
    
    /// Get total queue size
    public func getTotalQueueSize() -> Int {
        inMemoryQueue.count
    }
    
    // MARK: - Event Processing Callbacks
    
    /// Register event processing callback
    public func registerProcessingCallback(
        _ callback: @escaping (Event) async throws -> Void
    ) {
        processingCallbacks.append(callback)
    }
    
    // MARK: - Persistence
    
    /// Load queued events from database on startup
    public func loadFromDatabase() async throws {
        let events: [Event] = try await storage.read { db in
            try Event.filter(Column("processed") == false)
                .order(Column("timestamp"))
                .fetchAll(db)
        }
        
        inMemoryQueue = events
    }
    
    /// Get all unprocessed events from database
    public func getUnprocessedEvents() async throws -> [Event] {
        try await storage.read { db in
            try Event.filter(Column("processed") == false)
                .order(Column("timestamp"))
                .fetchAll(db)
        }
    }
    
    /// Delete old processed events (cleanup)
    public func cleanupOldEvents(olderThan: TimeInterval) async throws {
        let cutoffDate = Date().addingTimeInterval(-olderThan)
        
        try await storage.write { db in
            try db.execute(
                sql: """
                DELETE FROM events
                WHERE processed = 1 AND timestamp < ?
                """,
                arguments: [cutoffDate]
            )
        }
    }
}

// MARK: - Event Codable Extensions

extension Event {
    /// Insert event into database
    fileprivate mutating func insert(_ db: GRDB.Database) throws {
        try db.execute(
            sql: """
            INSERT INTO events (id, routeID, type, timestamp, payload, processed)
            VALUES (?, ?, ?, ?, ?, 0)
            """,
            arguments: [id, routeID, type.rawValue, timestamp, payload]
        )
    }
}

// MARK: - GRDB Helpers

import GRDB

private extension Event {
    static func filter(_ condition: SQLSpecificExpressible) -> QueryInterfaceRequest<Event> {
        Event.filter(condition)
    }
}
