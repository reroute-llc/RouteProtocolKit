# Phase 3: Events & State Management Migration

## Overview
This phase migrates event handling and state management from the C SDK to the Swift SDK, enabling modern async/await patterns and better type safety.

## Current State (C SDK)

### Event Handling
- Events are received via C callbacks: `rp_set_event_handler()`
- Events are processed synchronously in `handleServerEvent()` in RouteProtocolEngine
- Event types: MESSAGE_RECEIVED, REACTION_ADDED, TYPING_INDICATOR, etc.
- Events are immediately processed and saved to GRDB

### State Management
- Route states managed via C SDK: `rp_update_route_state()`
- States tracked in GRDB `routes` table
- No centralized state change notifications
- State changes trigger UI updates via `@Published` properties

## Target State (Swift SDK)

### Event Handling
- Events received via async Swift methods
- Event queue for offline/disconnected scenarios
- Typed event payloads with Codable conformance
- Actor-based thread-safety
- Event processing callbacks for flexibility

### State Management
- Centralized `RouteStateManager` actor
- State change notifications via async streams
- Automatic state persistence
- Better error handling with typed errors

## Migration Strategy

### Step 1: Parallel Event Handling ✓
- Keep C SDK event handler active
- Add Swift SDK event processing
- Log both for comparison
- **Strategy**: `parallel` mode in adapter

### Step 2: Event Queue Integration
- Route events through Swift SDK EventQueueManager
- Handle offline queuing automatically
- Process queued events on reconnection
- **Strategy**: `parallelSwiftPrimary` mode

### Step 3: State Management Migration
- Replace C SDK state updates with Swift SDK
- Use RouteStateManager for all state changes
- Implement state change observers
- **Strategy**: `swiftSDKOnly` for state

### Step 4: Remove C SDK Event Handler
- Disable C SDK event callbacks
- Fully rely on Swift SDK
- Remove compatibility shims
- **Strategy**: `swiftSDKOnly` for events

## Implementation Tasks

### Task 1: Update SDKMigrationAdapter for Events ✓
```swift
// Add event strategy
private var eventStrategy: MigrationStrategy = .parallel

// Event handling method
func handleEvent(_ event: Event) async throws {
    switch eventStrategy {
    case .cSDKOnly:
        // Keep current C SDK flow
        break
    case .parallel:
        // Log to both
        try await swiftSDK.queueEvent(event)
        // Also process via C SDK
        break
    case .swiftSDKOnly, .parallelSwiftPrimary:
        try await swiftSDK.queueEvent(event)
        break
    }
}
```

### Task 2: Create Event Bridge in RouteProtocolEngine
```swift
// Convert C SDK events to Swift SDK events
private func bridgeEventToSwiftSDK(_ type: String, _ payload: Data, _ routeID: String) async {
    guard let eventType = mapEventType(type) else { return }
    
    let event = Event(
        routeID: routeID,
        type: eventType,
        payload: payload
    )
    
    try? await migrationAdapter?.handleEvent(event)
}
```

### Task 3: Migrate State Management
```swift
// In RouteProtocolEngine
func updateRouteState(_ routeID: String, _ state: RouteState) async {
    // Update Swift SDK
    await swiftSDK?.stateManager.setState(routeID: routeID, state: state)
    
    // Update GRDB for UI
    try? await updateRouteInDatabase(routeID: routeID, state: state)
}
```

### Task 4: Event Processing Callbacks
```swift
// Register callback in RouteProtocolEngine.init()
await swiftSDK?.eventQueue.registerProcessingCallback { [weak self] event in
    await self?.processEventFromQueue(event)
}

private func processEventFromQueue(_ event: Event) async {
    // Decode payload and handle based on type
    switch event.type {
    case .messageReceived:
        await handleMessageReceived(event)
    case .reactionAdded:
        await handleReactionAdded(event)
    // ... etc
    }
}
```

## Code Changes

### Files to Modify
1. **`SDKMigrationAdapter.swift`**
   - Add event handling methods
   - Add state management bridge
   - Implement parallel mode for events

2. **`RouteProtocolEngine.swift`**
   - Add event bridge from C callbacks
   - Update state management calls
   - Register event processing callbacks
   - Add async event handlers

3. **`RouteProtocolSDK.swift`** (if needed)
   - Ensure event queue is properly initialized
   - Add convenience methods for event handling

## Benefits

### Immediate Wins
- ✅ Event queuing during disconnections
- ✅ Automatic event replay on reconnection
- ✅ Better error handling
- ✅ Type-safe event payloads

### Long-term Benefits
- ✅ Removal of C SDK dependency
- ✅ Modern Swift concurrency patterns
- ✅ Better testability
- ✅ Easier debugging with structured events

## Testing Plan

### Unit Tests
- Test event queuing and dequeuing
- Test state transitions
- Test offline event queuing
- Test event replay logic

### Integration Tests
1. Disconnect route → send messages → reconnect → verify queued events processed
2. State changes propagate correctly
3. Multiple routes handle events independently
4. Event callbacks fire in correct order

### Manual Testing
1. Send message while connected → verify immediate delivery
2. Disconnect → send message → reconnect → verify queued and delivered
3. Monitor state changes in UI
4. Verify no duplicate events

## Rollback Plan
If issues arise:
1. Change adapter strategy back to `.cSDKOnly`
2. Disable Swift SDK event callbacks
3. Keep C SDK as primary
4. Debug and fix Swift SDK issues
5. Re-enable gradually

## Success Criteria
- ✅ All events route through Swift SDK
- ✅ Event queue handles offline scenarios
- ✅ State management uses Swift SDK
- ✅ No duplicate events
- ✅ No crashes or data loss
- ✅ Performance equivalent or better

## Timeline
- **Event Bridge Setup**: 1 hour
- **Parallel Mode Testing**: 2 hours
- **State Migration**: 1 hour
- **Event Queue Integration**: 2 hours
- **Testing & Refinement**: 2 hours
- **Total**: ~8 hours (1 day)

---

**Status**: Ready to implement
**Current Phase**: Phase 3 - Events & State Management
**Next Phase**: Phase 4 - Security & Cleanup
