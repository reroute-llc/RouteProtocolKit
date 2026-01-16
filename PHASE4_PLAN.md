# Phase 4: Security & Cleanup Migration

## Overview
Phase 4 focuses on migrating security features, reconnection logic, and removing C SDK dependencies. This is the final phase before fully transitioning to the Swift SDK.

## Current State

### Security (C SDK)
- **Session Storage**: Route-specific data stored via C SDK `rp_set_session_data()` / `rp_get_session_data()`
- **Encryption**: Currently using `MetadataEncryptionManager` (app-level)
- **Keychain**: Mixed usage between app and C SDK

### Reconnection (C SDK + Go SDK)
- **C SDK**: Basic reconnection via `rp_reconnect_route()`
- **Go SDK**: Advanced reconnection management in routes (Discord, WhatsApp)
- **No centralized reconnection**: Each route handles its own reconnection

### Current Issues
1. Mixed security implementations (C SDK, app-level, keychain)
2. Reconnection logic split between C SDK and Go routes
3. No unified retry policy
4. C SDK still required for core functionality

## Target State (Swift SDK)

### Security
- **Session Storage**: `SessionStorageManager` with encryption
- **Keychain Integration**: Unified keychain access via `SecurityManager`
- **Secure Enclave**: Hardware-backed key storage
- **Encryption**: AES-256-GCM with proper key management

### Reconnection
- **Centralized Management**: `ReconnectionManager` in Swift SDK
- **Exponential Backoff**: Configurable retry policies
- **Health Checks**: Automatic connection monitoring
- **State Coordination**: Works with `RouteStateManager`

### Retry Logic
- **Unified Policies**: `RetryManager` for all operations
- **Configurable Strategies**: Per-operation retry configuration
- **Context Cancellation**: Proper cleanup on failures

## Migration Strategy

### Step 1: Session Storage Migration
Migrate route-specific session data from C SDK to Swift SDK.

**Current Flow:**
```
Route → C SDK rp_set_session_data() → SQLite → Encryption
```

**Target Flow:**
```
Route → Swift SDK SessionStorageManager → Keychain/Secure Storage
```

**Implementation:**
1. Add session storage methods to `SDKMigrationAdapter`
2. Intercept C SDK session storage calls
3. Route to Swift SDK `SessionStorageManager`
4. Migrate existing session data

### Step 2: Reconnection Migration
Replace C SDK reconnection with Swift SDK reconnection.

**Current Flow:**
```
Route Disconnect → C SDK rp_reconnect_route() → Manual Retry
```

**Target Flow:**
```
Route Disconnect → Swift SDK ReconnectionManager → Automatic Retry
```

**Implementation:**
1. Add reconnection methods to `SDKMigrationAdapter`
2. Configure reconnection policies per route
3. Integrate with `RouteStateManager`
4. Handle reconnection events

### Step 3: Remove C SDK Event Handler
Now that events flow through Swift SDK, remove C SDK callback.

**Implementation:**
1. Switch event strategy to `.swiftSDKOnly`
2. Disable C SDK `setEventCallback`
3. Process events entirely through Swift SDK
4. Remove event bridging code

### Step 4: Cleanup and Optimization
Remove unused C SDK code and optimize Swift SDK.

**Implementation:**
1. Identify unused C SDK functions
2. Remove compatibility shims
3. Optimize Swift SDK performance
4. Update documentation

## Implementation Tasks

### Task 1: Session Storage in SDKMigrationAdapter

```swift
// Add to SDKMigrationAdapter
extension SDKMigrationAdapter {
    /// Store session data for a route
    func setSessionData(routeID: String, key: String, value: String) async throws {
        switch strategies.security {
        case .cSDKOnly:
            // Use C SDK (existing flow)
            try cSDKWrapper?.setSessionData(routeID: routeID, key: key, value: value)
            
        case .parallel:
            // Store in both SDKs
            try cSDKWrapper?.setSessionData(routeID: routeID, key: key, value: value)
            try await swiftSDK?.storage.setSessionData(routeID: routeID, key: key, value: value)
            
        case .parallelSwiftPrimary, .swiftSDKOnly:
            // Use Swift SDK
            try await swiftSDK?.storage.setSessionData(routeID: routeID, key: key, value: value)
        }
    }
    
    /// Get session data for a route
    func getSessionData(routeID: String, key: String) async throws -> String? {
        switch strategies.security {
        case .cSDKOnly, .parallel:
            // C SDK is source of truth
            return try cSDKWrapper?.getSessionData(routeID: routeID, key: key)
            
        case .parallelSwiftPrimary, .swiftSDKOnly:
            // Swift SDK is source of truth
            return try await swiftSDK?.storage.getSessionData(routeID: routeID, key: key)
        }
    }
    
    /// Delete session data for a route
    func deleteSessionData(routeID: String, key: String) async throws {
        switch strategies.security {
        case .cSDKOnly:
            try cSDKWrapper?.deleteSessionData(routeID: routeID, key: key)
            
        case .parallel:
            try cSDKWrapper?.deleteSessionData(routeID: routeID, key: key)
            try await swiftSDK?.storage.deleteSessionData(routeID: routeID, key: key)
            
        case .parallelSwiftPrimary, .swiftSDKOnly:
            try await swiftSDK?.storage.deleteSessionData(routeID: routeID, key: key)
        }
    }
}
```

### Task 2: Reconnection in SDKMigrationAdapter

```swift
// Add to SDKMigrationAdapter
extension SDKMigrationAdapter {
    /// Enable reconnection for a route
    func enableReconnection(
        routeID: String,
        config: ReconnectionConfig = .default
    ) async throws {
        switch strategies.reconnection {
        case .cSDKOnly:
            // C SDK handles reconnection
            break
            
        case .parallel, .parallelSwiftPrimary:
            // Configure Swift SDK reconnection
            await swiftSDK?.reconnection.configure(
                routeID: routeID,
                config: config
            )
            
        case .swiftSDKOnly:
            // Swift SDK handles all reconnection
            await swiftSDK?.reconnection.configure(
                routeID: routeID,
                config: config
            )
        }
    }
    
    /// Trigger reconnection for a route
    func triggerReconnection(routeID: String) async throws {
        switch strategies.reconnection {
        case .cSDKOnly:
            // Use C SDK
            try cSDKWrapper?.reconnectRoute(routeID: routeID)
            
        case .parallel:
            // Try both
            try cSDKWrapper?.reconnectRoute(routeID: routeID)
            _ = try await swiftSDK?.reconnection.triggerReconnection(routeID: routeID)
            
        case .parallelSwiftPrimary, .swiftSDKOnly:
            // Use Swift SDK
            _ = try await swiftSDK?.reconnection.triggerReconnection(routeID: routeID)
        }
    }
    
    /// Check if reconnection is enabled
    func canReconnect(routeID: String) async -> Bool {
        switch strategies.reconnection {
        case .cSDKOnly, .parallel:
            return false // C SDK doesn't expose this
            
        case .parallelSwiftPrimary, .swiftSDKOnly:
            return await swiftSDK?.reconnection.canReconnect(routeID: routeID) ?? false
        }
    }
}
```

### Task 3: Remove C SDK Event Handler

```swift
// In RouteProtocolEngine.init()
// Remove or disable C SDK event callback
// sdkWrapper.setEventCallback { ... }  // REMOVE THIS

// Instead, process events entirely through Swift SDK
Task { @MainActor in
    await self.setupSwiftSDKEventProcessing()
}

private func setupSwiftSDKEventProcessing() async {
    guard let swiftSDK = swiftSDK else { return }
    
    // Register event processing callback
    await swiftSDK.eventQueue.registerProcessingCallback { [weak self] event in
        await self?.processEventFromSwiftSDK(event)
    }
}

private func processEventFromSwiftSDK(_ event: RouteProtocolKit.Event) async {
    // Decode event payload and process
    do {
        let routeEvent = try JSONDecoder().decode(RouteProtocolEvent.self, from: event.payload)
        
        // Send to existing event subject (UI listens to this)
        await MainActor.run {
            self.eventSubject.send(routeEvent)
        }
    } catch {
        print("⚠️ Failed to decode event from Swift SDK: \(error)")
    }
}
```

### Task 4: Session Storage Helper Methods

Add convenience methods to `StorageManager` for session data:

```swift
// In StorageManager.swift
extension StorageManager {
    /// Store session data for a route
    public func setSessionData(routeID: String, key: String, value: String) throws {
        try write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO session_storage (route_id, key, value, updated_at)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [routeID, key, value, Date()]
            )
        }
    }
    
    /// Get session data for a route
    public func getSessionData(routeID: String, key: String) throws -> String? {
        try read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM session_storage WHERE route_id = ? AND key = ?",
                arguments: [routeID, key]
            )
        }
    }
    
    /// Delete session data for a route
    public func deleteSessionData(routeID: String, key: String? = nil) throws {
        try write { db in
            if let key = key {
                try db.execute(
                    sql: "DELETE FROM session_storage WHERE route_id = ? AND key = ?",
                    arguments: [routeID, key]
                )
            } else {
                try db.execute(
                    sql: "DELETE FROM session_storage WHERE route_id = ?",
                    arguments: [routeID]
                )
            }
        }
    }
    
    /// Get all session data for a route
    public func getAllSessionData(routeID: String) throws -> [String: String] {
        try read { db in
            var data: [String: String] = [:]
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT key, value FROM session_storage WHERE route_id = ?",
                arguments: [routeID]
            )
            for row in rows {
                let key: String = row["key"]
                let value: String = row["value"]
                data[key] = value
            }
            return data
        }
    }
}
```

## Code Changes Required

### Files to Modify

1. **`SDKMigrationAdapter.swift`**
   - Add session storage methods
   - Add reconnection methods
   - Update migration strategies

2. **`RouteProtocolEngine.swift`**
   - Remove C SDK event callback (or disable)
   - Add Swift SDK event processing
   - Update session storage calls to use adapter

3. **`StorageManager.swift`** (Swift SDK)
   - Add session storage helper methods
   - Ensure encryption for sensitive data

4. **`RouteProtocolSDK.swift`** (Swift SDK)
   - Expose session storage via storage manager
   - Already has reconnection manager

### Files to Create

1. **`PHASE4_COMPLETE.md`** - Completion summary
2. **`MIGRATION_COMPLETE.md`** - Overall migration summary

## Benefits

### Security Benefits
- ✅ **Unified Encryption**: Single source of truth for encryption
- ✅ **Secure Enclave**: Hardware-backed key storage
- ✅ **Better Key Management**: Automatic key rotation and management
- ✅ **Keychain Integration**: Proper secure storage

### Reconnection Benefits
- ✅ **Automatic Retry**: No manual reconnection code needed
- ✅ **Exponential Backoff**: Smart retry delays
- ✅ **Health Checks**: Proactive connection monitoring
- ✅ **State Coordination**: Works with state manager

### Cleanup Benefits
- ✅ **Remove C SDK**: No more C dependencies
- ✅ **Modern Swift**: Full async/await patterns
- ✅ **Better Testing**: Easier to test and mock
- ✅ **Reduced Complexity**: Single SDK to maintain

## Testing Strategy

### Phase 4a: Session Storage Testing
1. Enable `.parallel` mode for security
2. Store session data via adapter
3. Verify data in both C SDK and Swift SDK
4. Switch to `.swiftSDKOnly`
5. Verify session data persists correctly

### Phase 4b: Reconnection Testing
1. Enable reconnection for a route
2. Disconnect route manually
3. Verify automatic reconnection
4. Test exponential backoff
5. Test max attempts limit

### Phase 4c: Event Processing Testing
1. Disable C SDK event callback
2. Process events via Swift SDK only
3. Verify all event types work
4. Test offline event queuing
5. Test event replay on reconnection

### Phase 4d: Integration Testing
1. Connect/disconnect routes
2. Send messages while disconnected
3. Verify queuing and replay
4. Test state transitions
5. Verify no data loss

## Rollback Plan

### If Issues Arise:

**Step 1:** Re-enable C SDK features
```swift
adapter.enableFeature(\.security, strategy: .cSDKOnly)
adapter.enableFeature(\.reconnection, strategy: .cSDKOnly)
adapter.enableFeature(\.events, strategy: .parallel)  // Keep parallel for events
```

**Step 2:** Verify C SDK works
- Test session storage
- Test reconnection
- Test event processing

**Step 3:** Debug Swift SDK issues
- Check logs for errors
- Fix Swift SDK bugs
- Re-test in isolation

**Step 4:** Re-enable gradually
- Start with `.parallel` mode
- Monitor for issues
- Switch to `.swiftSDKOnly` when stable

## Success Criteria

### Phase 4 Complete When:
- ✅ Session storage works via Swift SDK
- ✅ Reconnection works automatically
- ✅ Events process entirely via Swift SDK
- ✅ C SDK event callback removed/disabled
- ✅ No data loss or corruption
- ✅ All tests pass
- ✅ Performance meets or exceeds C SDK

## Timeline

- **Session Storage Migration**: 2 hours
- **Reconnection Migration**: 2 hours
- **Event Processing Cleanup**: 1 hour
- **Testing & Refinement**: 3 hours
- **Documentation**: 1 hour
- **Total**: ~9 hours (1 day)

## Next Steps After Phase 4

### Phase 5: Final Cleanup
1. Remove all C SDK code
2. Remove `SDKMigrationAdapter` (no longer needed)
3. Update all routes to use Swift SDK directly
4. Remove compatibility shims
5. Optimize performance
6. Update documentation
7. Celebrate completion! 🎉

---

**Status**: Ready to implement
**Current Phase**: Phase 4 - Security & Cleanup
**Next Phase**: Phase 5 - Final Cleanup & Optimization
