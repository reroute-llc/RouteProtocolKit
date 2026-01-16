import Foundation
import GRDB

/// Storage manager using GRDB (preserving existing patterns)
public actor StorageManager {
    public let dbQueue: DatabaseQueue // ✅ Public for app's type-safe GRDB queries
    private let databasePath: String
    
    // MARK: - Initialization
    
    public init(path: String, passphrase: String? = nil) throws {
        self.databasePath = path
        
        var config = Configuration()
        config.prepareDatabase { db in
            // WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            
            // If passphrase provided, use SQLCipher
            if let passphrase = passphrase {
                try db.execute(sql: "PRAGMA key = '\(passphrase)'")
            }
        }
        
        // Create database queue
        self.dbQueue = try DatabaseQueue(path: path, configuration: config)
        
        // Apply iOS File Protection (.complete)
        try Self.protectDatabaseFile(at: path)
        
        // Run migrations (must be called from nonisolated context)
        try migrateDatabaseSync()
    }
    
    // MARK: - File Protection
    
    private static func protectDatabaseFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        
        // Complete protection - encrypted when device locked
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        
        // Exclude from backup (sensitive data)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }
    
    // MARK: - Database Operations
    
    /// Read operation (thread-safe via DatabaseQueue)
    public func read<T>(_ block: (Database) throws -> T) async throws -> T {
        try dbQueue.read(block)
    }
    
    /// Write operation (thread-safe via DatabaseQueue)
    public func write<T>(_ block: (Database) throws -> T) async throws -> T {
        try dbQueue.write(block)
    }
    
    // MARK: - Migrations
    
    private nonisolated func migrateDatabaseSync() throws {
        var migrator = DatabaseMigrator()
        
        // v1: Initial schema
        migrator.registerMigration("v1_initial_schema") { db in
            // Routes table
            try db.create(table: "routes") { t in
                t.column("id", .text).primaryKey()
                t.column("platform", .text).notNull()
                t.column("displayName", .text).notNull()
                t.column("state", .text).notNull()
                t.column("metadata", .text) // JSON
                t.column("createdAt", .datetime).notNull()
                t.column("lastConnectedAt", .datetime)
            }
            
            // Conversations table
            try db.create(table: "conversations") { t in
                t.column("id", .text).primaryKey()
                t.column("routeID", .text).notNull()
                    .indexed()
                    .references("routes", onDelete: .cascade)
                t.column("displayName", .text).notNull()
                t.column("avatarURL", .text)
                t.column("lastMessageText", .text)
                t.column("lastMessageTimestamp", .datetime)
                t.column("unreadCount", .integer).notNull().defaults(to: 0)
                t.column("isGroup", .boolean).notNull().defaults(to: false)
                t.column("participantIDs", .text) // JSON array
                t.column("metadata", .text) // JSON
            }
            
            // Messages table
            try db.create(table: "messages") { t in
                t.column("id", .text).primaryKey()
                t.column("conversationID", .text).notNull()
                    .indexed()
                    .references("conversations", onDelete: .cascade)
                t.column("senderID", .text).notNull()
                t.column("contentType", .text).notNull()
                t.column("text", .text)
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("status", .text).notNull()
                t.column("replyToMessageID", .text)
                t.column("replyToPreview", .text)
                t.column("platformMessageID", .text)
                t.column("attachmentMetadata", .text) // JSON
            }
            
            // Events table (for queued events)
            try db.create(table: "events") { t in
                t.column("id", .text).primaryKey()
                t.column("routeID", .text).notNull().indexed()
                t.column("type", .text).notNull()
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("payload", .blob).notNull()
                t.column("processed", .boolean).notNull().defaults(to: false)
            }
            
            // Session storage table (for route-specific data)
            try db.create(table: "session_storage") { t in
                t.column("key", .text).primaryKey()
                t.column("routeID", .text).notNull().indexed()
                t.column("value", .blob).notNull()
                t.column("expiresAt", .datetime)
                t.column("createdAt", .datetime).notNull()
            }
        }
        
        try migrator.migrate(dbQueue)
    }
    
    // MARK: - Convenience Methods
    
    /// Check if database exists
    public nonisolated static func databaseExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    /// Get database size in bytes
    public func getDatabaseSize() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: databasePath)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// Vacuum database (reclaim space)
    public func vacuum() async throws {
        try await write { db in
            try db.execute(sql: "VACUUM")
        }
    }
    
    /// Close database
    public func close() async throws {
        // GRDB DatabaseQueue automatically handles closing
        // This method is here for API completeness
    }
}

// MARK: - GRDB Record Extensions

extension Route: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "routes" }
    
    public enum Columns: String, ColumnExpression {
        case id, platform, displayName, state, metadata, createdAt, lastConnectedAt
    }
}

extension Conversation: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "conversations" }
    
    public enum Columns: String, ColumnExpression {
        case id, routeID, displayName, avatarURL, lastMessageText, lastMessageTimestamp
        case unreadCount, isGroup, participantIDs, metadata
    }
}

extension Message: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "messages" }
    
    public enum Columns: String, ColumnExpression {
        case id, conversationID, senderID, contentType, text, timestamp, status
        case replyToMessageID, replyToPreview, platformMessageID, attachmentMetadata
    }
}

extension Event: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "events" }
    
    public enum Columns: String, ColumnExpression {
        case id, routeID, type, timestamp, payload, processed
    }
}
