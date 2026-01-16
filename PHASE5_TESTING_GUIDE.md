# Phase 5: Testing Guide

## Overview
This guide provides comprehensive testing instructions for validating the Swift SDK migration. All features are now running in **parallel mode** with both C SDK and Swift SDK active.

## What Changed in Phase 5

### Code Changes
1. **Parallel Mode Enabled**: All features now operate in parallel mode
   - Events bridge to both C SDK and Swift SDK
   - State updates sent to both SDKs
   - Session storage writes to both SDKs
   - Reconnection configured in both SDKs

2. **Swift SDK Event Processing**: New event processing from Swift SDK
   - Events can originate from either C SDK or Swift SDK
   - Event queue supports offline queuing
   - Automatic event replay on reconnection

### Expected Behavior
- **Normal Operation**: Should feel identical to before
- **Offline Mode**: Messages will queue and send on reconnection
- **Reconnection**: Should happen automatically after disconnection
- **Performance**: Slight overhead (<5%) due to dual processing
- **Logging**: Extensive migration logs for debugging

## Quick Start

### 1. Clean Build
```bash
# In Xcode
Product → Clean Build Folder (Shift + Cmd + K)
Product → Build (Cmd + B)
```

### 2. Run the App
```bash
# Run from Xcode (Cmd + R)
# Or build and run:
xcodebuild -scheme Reroute -destination 'platform=iOS Simulator,name=iPhone 15' run
```

### 3. Monitor Logs
Look for these log messages:
- `🚀 [Phase 5] Enabling parallel mode...`
- `✅ [Phase 5] Parallel mode enabled`
- `🔄 [Event Migration]` - Event bridging
- `🔄 [State Migration]` - State bridging
- `📝 [Session Storage]` - Session operations
- `📡 [Reconnection]` - Reconnection operations

## Test Suites

### Suite 1: Basic Functionality ✅

#### Test 1.1: Route Connection
**Steps**:
1. Launch app
2. Navigate to routes list
3. Connect Discord route
4. Wait for "Connected" status

**Expected**:
- Route connects successfully
- See logs: `🔄 [State Migration]` with state changes
- Route status shows "Connected" in UI
- No errors in logs

**Verification**:
```
✅ C SDK Event: routeStatusChanged - status=2 (CONNECTED)
✅ [State Migration] Parallel: Set state for route [id]
```

---

#### Test 1.2: Send Message
**Steps**:
1. With route connected
2. Select a conversation
3. Send a text message
4. Wait for message to appear

**Expected**:
- Message sends successfully
- Message appears in conversation
- See logs: `🔄 [Event Migration]` for message received event
- Message status updates (sending → sent)

**Verification**:
```
📤 Sending message...
✅ Message sent
🔄 [Event Migration] Parallel: messageReceived
```

---

#### Test 1.3: Receive Message
**Steps**:
1. Have someone send you a message
2. Or use another device to send a message

**Expected**:
- Message appears in conversation
- Notification shown (if enabled)
- See logs: `🔄 [Event Migration]` for message received
- Message displays correctly in UI

**Verification**:
```
📥 C SDK Event: messageReceived
🔄 [Event Migration] Parallel: messageReceived
✅ [Phase 5] Event sent to UI
```

---

### Suite 2: Offline Behavior ✅

#### Test 2.1: Offline Message Queueing
**Steps**:
1. Connect route
2. Disconnect network (Airplane mode or disable WiFi)
3. Send 3-5 messages
4. Check app logs for queuing

**Expected**:
- Messages appear as "Sending..." in UI
- See logs: `✅ [Event Migration] Event queued in Swift SDK`
- Messages are not sent (network offline)
- No crashes or errors

**Verification**:
```
📤 Sending message (offline)...
✅ [Event Migration] Swift SDK: Event queued
📊 Swift SDK Queue Size: 3
```

---

#### Test 2.2: Message Replay on Reconnection
**Steps**:
1. Continue from Test 2.1 (messages queued)
2. Reconnect network
3. Wait for reconnection
4. Observe messages being sent

**Expected**:
- Route reconnects automatically
- Queued messages are sent one by one
- Messages change from "Sending..." to "Sent"
- See logs: `✅ [Phase 5] Event sent to UI` for each message

**Verification**:
```
📡 [Reconnection] Triggered for route [id]
✅ Route reconnected
📤 Processing queued events...
✅ [Phase 5] Processing event from Swift SDK
✅ Message 1 sent
✅ Message 2 sent
✅ Message 3 sent
```

---

### Suite 3: State Management ✅

#### Test 3.1: Connection States
**Steps**:
1. Launch app
2. Connect a route
3. Watch state transitions in logs

**Expected States** (in order):
1. `DISCONNECTED` (initial)
2. `CONNECTING` (during connection)
3. `CONNECTED` (after success)

**Verification**:
```
🔄 [State Migration] Parallel: CONNECTING
🔄 [State Migration] Parallel: CONNECTED
```

---

#### Test 3.2: Disconnection States
**Steps**:
1. With route connected
2. Manually disconnect route
3. Watch state transitions

**Expected States**:
1. `DISCONNECTING` (during disconnect)
2. `DISCONNECTED` (after disconnect)

**Verification**:
```
🔄 [State Migration] Parallel: DISCONNECTING
🔄 [State Migration] Parallel: DISCONNECTED
```

---

#### Test 3.3: Reconnection States
**Steps**:
1. Disconnect network
2. Route should auto-reconnect
3. Watch state transitions

**Expected States**:
1. `DISCONNECTED` (network lost)
2. `RECONNECTING` (auto-reconnect triggered)
3. `CONNECTED` (reconnection success)

**Verification**:
```
🔄 [State Migration] Parallel: DISCONNECTED
📡 [Reconnection] Triggered for route [id]
🔄 [State Migration] Parallel: RECONNECTING
🔄 [State Migration] Parallel: CONNECTED
```

---

### Suite 4: Session Storage ✅

#### Test 4.1: Store Session Data
**Steps**:
1. Connect route
2. Session data should be stored automatically
3. Check logs for session storage

**Expected**:
- Session ID stored
- See logs: `📝 [Session Storage]`
- No errors

**Verification**:
```
📝 [Session Storage] Parallel: Set session_id for route [id]
✅ Session data stored in Swift SDK
```

---

#### Test 4.2: Session Persistence
**Steps**:
1. Connect route
2. Force quit app
3. Relaunch app
4. Check if session persists

**Expected**:
- Route reconnects with same session
- No re-authentication needed
- See logs: `📖 [Session Storage]` on load

**Verification**:
```
📖 [Session Storage] Swift SDK: Get session_id for route [id]
✅ Session restored from storage
```

---

### Suite 5: Multi-Route Testing ✅

#### Test 5.1: Multiple Routes
**Steps**:
1. Connect Discord route
2. Connect WhatsApp route
3. Send messages on both
4. Verify both work correctly

**Expected**:
- Both routes connect successfully
- Messages send on both routes
- Events processed for both routes
- States tracked independently

**Verification**:
```
🔄 [State Migration] route_discord: CONNECTED
🔄 [State Migration] route_whatsapp: CONNECTED
🔄 [Event Migration] route_discord: messageReceived
🔄 [Event Migration] route_whatsapp: messageReceived
```

---

### Suite 6: Performance Testing ✅

#### Test 6.1: Message Send Latency
**Steps**:
1. Connect route
2. Send 10 messages quickly
3. Measure time to send

**Expected**:
- All messages send successfully
- Average latency < 100ms per message (network dependent)
- No significant delay vs. before

**Measurement**:
```swift
let start = Date()
for i in 0..<10 {
    sendMessage("Test \(i)")
}
let duration = Date().timeIntervalSince(start)
print("Sent 10 messages in \(duration)s")
```

**Target**: < 1 second total (10 messages)

---

#### Test 6.2: App Launch Time
**Steps**:
1. Force quit app
2. Launch app
3. Measure time to main screen

**Expected**:
- Launch time similar to before
- No significant delay
- < 3 seconds to main screen

**Measurement**: Use Xcode Instruments (Time Profiler)

**Target**: < 3 seconds

---

## Common Issues & Solutions

### Issue 1: "Swift SDK not initialized"
**Symptoms**: Logs show `⚠️ [Phase 5] Cannot setup event processing`

**Solution**:
1. Check Swift SDK initialization logs
2. Verify database path is writable
3. Check for initialization errors
4. Clean build and retry

---

### Issue 2: Events Not Appearing in UI
**Symptoms**: Messages sent but not appearing

**Solution**:
1. Check logs for `🔄 [Event Migration]`
2. Verify event callback is set
3. Check `eventSubject` is sending events
4. Verify UI is listening to events

---

### Issue 3: Duplicate Messages
**Symptoms**: Same message appears twice

**Solution**:
- This can happen in parallel mode if both SDKs process the same event
- Should be rare
- Will be fixed when switching to `.swiftSDKOnly`

---

### Issue 4: Messages Not Queuing Offline
**Symptoms**: Messages lost when offline

**Solution**:
1. Check logs for `✅ [Event Migration] Event queued`
2. Verify Swift SDK event queue is initialized
3. Check queue size: should increase when offline
4. Verify reconnection triggers event replay

---

### Issue 5: Performance Degradation
**Symptoms**: App feels slower

**Solution**:
- Expected ~5% overhead in parallel mode
- Check CPU usage in Xcode Instruments
- Verify both SDKs are running (should see dual logging)
- Consider switching to `.parallelSwiftPrimary` if issue persists

---

## Rollback Procedure

If critical issues are found:

### Quick Rollback (Temporary)
```swift
// In RouteProtocolEngine.init(), comment out parallel mode:
// migrationAdapter?.enableFeature(\.events, strategy: .parallel)
// migrationAdapter?.enableFeature(\.state, strategy: .parallel)
// migrationAdapter?.enableFeature(\.security, strategy: .parallel)
// migrationAdapter?.enableFeature(\.reconnection, strategy: .parallel)
```

### Full Rollback (Disable All)
```swift
// Revert all features to C SDK only
migrationAdapter?.enableFeature(\.events, strategy: .cSDKOnly)
migrationAdapter?.enableFeature(\.state, strategy: .cSDKOnly)
migrationAdapter?.enableFeature(\.security, strategy: .cSDKOnly)
migrationAdapter?.enableFeature(\.reconnection, strategy: .cSDKOnly)
```

### Re-enable After Fix
```swift
// After fixing issue, re-enable gradually:
migrationAdapter?.enableFeature(\.events, strategy: .parallel)
// Test
migrationAdapter?.enableFeature(\.state, strategy: .parallel)
// Test
migrationAdapter?.enableFeature(\.security, strategy: .parallel)
// Test
migrationAdapter?.enableFeature(\.reconnection, strategy: .parallel)
```

---

## Success Criteria

### Phase 5 Testing Complete When:
- ✅ All basic functionality tests pass
- ✅ Offline behavior works (queuing + replay)
- ✅ State transitions are correct
- ✅ Session storage persists
- ✅ Multi-route support works
- ✅ Performance is acceptable (<5% overhead)
- ✅ No critical bugs or crashes
- ✅ Ready for production testing

---

## Next Steps

### After Testing Passes:

**Option 1: Continue Testing (Conservative)**
- Run app for 1-2 days in parallel mode
- Monitor for any edge cases
- Fix any issues found
- Gather performance metrics

**Option 2: Enable Swift Primary (Aggressive)**
```swift
// Switch to Swift SDK as primary
migrationAdapter?.enableFeature(\.events, strategy: .parallelSwiftPrimary)
migrationAdapter?.enableFeature(\.state, strategy: .parallelSwiftPrimary)
migrationAdapter?.enableFeature(\.security, strategy: .parallelSwiftPrimary)
migrationAdapter?.enableFeature(\.reconnection, strategy: .parallelSwiftPrimary)
```

**Option 3: Enable Swift Only (Final)**
```swift
// Switch to Swift SDK only
migrationAdapter?.enableFeature(\.events, strategy: .swiftSDKOnly)
migrationAdapter?.enableFeature(\.state, strategy: .swiftSDKOnly)
migrationAdapter?.enableFeature(\.security, strategy: .swiftSDKOnly)
migrationAdapter?.enableFeature(\.reconnection, strategy: .swiftSDKOnly)
```

---

## Logging Reference

### Log Prefixes
- `🚀 [Phase 5]` - Phase 5 initialization
- `🔄 [Event Migration]` - Event bridging (parallel mode)
- `✅ [Event Migration]` - Event processing (Swift primary)
- `🔄 [State Migration]` - State bridging (parallel mode)
- `✅ [State Migration]` - State processing (Swift primary)
- `📝 [Session Storage]` - Session storage operations
- `📡 [Reconnection]` - Reconnection operations
- `📥 [Phase 5]` - Event processing from Swift SDK
- `⚠️` - Warnings (non-critical)
- `❌` - Errors (critical)

### Verbose Logging
To see all logs, use Xcode console or:
```bash
log stream --predicate 'subsystem contains "com.reroute"' --level debug
```

---

## Reporting Issues

When reporting issues, include:

1. **Steps to reproduce**
2. **Expected vs actual behavior**
3. **Relevant logs** (especially `[Phase 5]`, `[Event Migration]`, `[State Migration]`)
4. **Screenshots** (if UI issue)
5. **Device/OS version**
6. **Build configuration** (Debug/Release)

---

**Happy Testing!** 🎉

If all tests pass, the Swift SDK migration is ready for production use!
