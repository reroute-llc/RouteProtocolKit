# Swift SDK Migration Plan (Sprint 4-6)

## Executive Summary

**Goal:** Replace C SDK (`RouteProtocolSDKWrapper`) with Swift SDK (`RouteProtocolKit`)  
**Duration:** 3 weeks (estimated)  
**Impact:** ~-3000 lines, better maintainability, pure Swift architecture  

---

## Current State Analysis

### C SDK Usage
```
Total Swift files: 36
Files importing C SDK: 1 (RouteProtocolSDKWrapper.swift)
C SDK wrapper: 1290 lines
Primary interfaces:
  - RouteProtocolEngine.swift
  - ChatSyncService.swift
  - EnhancedCryptoManager.swift
```

### Good News! 🎉
**C SDK usage is well-encapsulated!**
- ✅ Only `RouteProtocolSDKWrapper.swift` imports C SDK
- ✅ Rest of app uses Swift interfaces
- ✅ Clean abstraction layer exists
- ✅ Migration will be straightforward!

### Key Files

| File | Lines | Purpose | Migration Impact |
|------|-------|---------|------------------|
| `RouteProtocolSDKWrapper.swift` | 1290 | C SDK wrapper | ❌ **DELETE** |
| `RouteProtocolEngine.swift` | ~800 | Route management | ✏️ **REFACTOR** |
| `ChatSyncService.swift` | ~500 | Message sync | ✏️ **REFACTOR** |
| `EnhancedCryptoManager.swift` | ~600 | Encryption | ✏️ **MIGRATE** |
| Route Bridges (Discord/WhatsApp) | ~2000 | Route-specific | ✏️ **UPDATE** |

**Total:** ~5190 lines to touch (but most are simple replacements!)

---

## Migration Strategy

### Phase 1: Parallel Integration (Week 1)
**Goal:** Add Swift SDK alongside C SDK  
**Duration:** 2-3 days  
**Risk:** Low

**Tasks:**
1. Add RouteProtocolKit to Xcode project
2. Create migration adapter layer
3. Initialize both SDKs side-by-side
4. Test basic functionality

**Changes:**
```swift
// OLD (C SDK only):
let sdkWrapper = RouteProtocolSDKWrapper(storagePath: path)

// NEW (Both SDKs):
let sdkWrapper = RouteProtocolSDKWrapper(storagePath: path) // Keep for now
let swiftSDK = RouteProtocolSDK(databasePath: path) // Add
```

### Phase 2: Storage Migration (Week 1-2)
**Goal:** Migrate storage from C SDK to Swift SDK  
**Duration:** 3-4 days  
**Risk:** Medium

**Tasks:**
1. Migrate GRDB schema to Swift SDK
2. Update `ChatSyncService` to use Swift SDK storage
3. Migrate conversation/message queries
4. Test data persistence

**Changes:**
- Replace `RouteProtocolSDKWrapper` storage calls
- Use `StorageManager` from RouteProtocolKit
- Keep encryption with `EnhancedCryptoManager` (for now)

### Phase 3: Event & State Migration (Week 2)
**Goal:** Migrate event handling and state management  
**Duration:** 3-4 days  
**Risk:** Medium

**Tasks:**
1. Replace C SDK event callbacks with Swift SDK
2. Migrate route state management
3. Update `RouteProtocolEngine` event handling
4. Test real-time updates

**Changes:**
```swift
// OLD (C SDK):
sdkWrapper.setEventCallback { event in ... }

// NEW (Swift SDK):
await swiftSDK.setEventHandler { event in ... }
```

### Phase 4: Security Migration (Week 2-3)
**Goal:** Migrate crypto to Swift SDK  
**Duration:** 2-3 days  
**Risk:** High (data encryption!)

**Tasks:**
1. Audit `EnhancedCryptoManager` usage
2. Migrate to Swift SDK's `SecurityManager`
3. Ensure backward compatibility
4. Test encryption/decryption

**Changes:**
- Replace `EnhancedCryptoManager` calls
- Use `SecurityManager` from RouteProtocolKit
- Keep Secure Enclave integration

### Phase 5: Remove C SDK (Week 3)
**Goal:** Delete C SDK and RouteProtocolSDKWrapper  
**Duration:** 2-3 days  
**Risk:** Low

**Tasks:**
1. Remove all C SDK references
2. Delete `RouteProtocolSDKWrapper.swift` (1290 lines!)
3. Update Route Bridges
4. Clean up Xcode project

**Changes:**
- ❌ Delete `RouteProtocolSDKWrapper.swift`
- ❌ Remove C SDK framework
- ✅ Pure Swift architecture!

### Phase 6: Testing & Validation (Week 3)
**Goal:** Comprehensive testing  
**Duration:** 2-3 days  
**Risk:** Low

**Tasks:**
1. Test all routes (Discord, WhatsApp)
2. Test message sending/receiving
3. Test encryption/decryption
4. Test reconnection scenarios
5. Performance testing

---

## Detailed Task Breakdown

### Week 1: Foundation & Storage

#### Day 1-2: Parallel Integration
- ⏳ Add RouteProtocolKit to Xcode project
- ⏳ Initialize Swift SDK in `RouteProtocolEngine`
- ⏳ Create adapter layer for gradual migration
- ⏳ Test basic initialization

#### Day 3-4: Storage Migration Part 1
- ⏳ Migrate GRDB schema to Swift SDK
- ⏳ Update conversation queries
- ⏳ Update message queries
- ⏳ Test data persistence

#### Day 5: Storage Migration Part 2
- ⏳ Migrate `ChatSyncService` storage calls
- ⏳ Test message sync
- ⏳ Test conversation loading

### Week 2: Events & State

#### Day 6-7: Event Migration
- ⏳ Replace C SDK event callbacks
- ⏳ Update `RouteProtocolEngine` event handling
- ⏳ Test message received events
- ⏳ Test typing indicators

#### Day 8-9: State Migration
- ⏳ Migrate route state management
- ⏳ Update connection state handling
- ⏳ Test reconnection scenarios
- ⏳ Test state persistence

#### Day 10: Event Queue & Reconnection
- ⏳ Migrate event queue to Swift SDK
- ⏳ Test reconnection manager
- ⏳ Test health checks
- ⏳ Test offline message queuing

### Week 3: Security & Cleanup

#### Day 11-12: Security Migration
- ⏳ Audit `EnhancedCryptoManager` usage
- ⏳ Migrate to Swift SDK `SecurityManager`
- ⏳ Test encryption/decryption
- ⏳ Test key rotation

#### Day 13-14: C SDK Removal
- ⏳ Remove C SDK references
- ⏳ Delete `RouteProtocolSDKWrapper.swift`
- ⏳ Update Route Bridges
- ⏳ Clean up Xcode project

#### Day 15: Testing & Validation
- ⏳ Comprehensive testing
- ⏳ Performance testing
- ⏳ Bug fixes
- ⏳ Documentation

---

## Risk Assessment

### High Risk Areas
1. **Encryption Migration** (Phase 4)
   - Risk: Data loss or corruption
   - Mitigation: Extensive testing, backward compatibility
   - Fallback: Keep `EnhancedCryptoManager` longer

2. **Event Callback Migration** (Phase 3)
   - Risk: Missed events, race conditions
   - Mitigation: Parallel event handlers during migration
   - Fallback: Revert to C SDK event handling

3. **Storage Migration** (Phase 2)
   - Risk: Data migration issues
   - Mitigation: Database backup, migration scripts
   - Fallback: Keep C SDK storage longer

### Medium Risk Areas
1. **Route Bridge Updates**
   - Risk: Breaking route functionality
   - Mitigation: Test each route independently
   
2. **State Management**
   - Risk: Inconsistent state
   - Mitigation: Use Swift SDK's StateManager

### Low Risk Areas
1. **UI Updates**
   - Risk: Minimal (mostly data binding changes)
   
2. **Initialization**
   - Risk: Low (both SDKs can coexist)

---

## Migration Checkpoints

### Checkpoint 1: Week 1 End
**Criteria:**
- ✅ Swift SDK integrated
- ✅ Storage migrated
- ✅ Conversations load correctly
- ✅ Messages load correctly

**Decision Point:** Continue or address storage issues

### Checkpoint 2: Week 2 End
**Criteria:**
- ✅ Events migrated
- ✅ State management migrated
- ✅ Real-time updates work
- ✅ Reconnection works

**Decision Point:** Continue or address event issues

### Checkpoint 3: Week 3 End
**Criteria:**
- ✅ Encryption migrated
- ✅ C SDK removed
- ✅ All tests pass
- ✅ Performance acceptable

**Decision Point:** Ship or address final issues

---

## Success Criteria

### Functional
- ✅ All routes connect successfully
- ✅ Messages send/receive correctly
- ✅ Encryption/decryption works
- ✅ Reconnection works
- ✅ Event handling works
- ✅ State management works

### Technical
- ✅ C SDK removed
- ✅ RouteProtocolSDKWrapper deleted (1290 lines)
- ✅ Swift SDK integrated
- ✅ All tests pass
- ✅ No compilation errors

### Quality
- ✅ Code is cleaner
- ✅ Maintainability improved
- ✅ Performance acceptable
- ✅ No regressions

---

## Expected Code Reduction

| Item | Before | After | Savings |
|------|--------|-------|---------|
| **RouteProtocolSDKWrapper** | 1290 lines | 0 lines | **-1290 lines** |
| **C SDK bridging** | ~500 lines | 0 lines | **-500 lines** |
| **Duplicate storage logic** | ~300 lines | 0 lines (SDK) | **-300 lines** |
| **Duplicate event logic** | ~200 lines | 0 lines (SDK) | **-200 lines** |
| **Duplicate state logic** | ~150 lines | 0 lines (SDK) | **-150 lines** |
| **Crypto simplification** | ~200 lines | ~50 lines | **-150 lines** |
| **Route Bridge simplification** | ~500 lines | ~200 lines | **-300 lines** |
| **Total** | **~3140 lines** | **~250 lines** | **~-2890 lines** 🎉 |

---

## Rollback Plan

### If Migration Fails (Unlikely)

**Phase 1-2 Issues:**
- Keep C SDK wrapper
- Revert storage changes
- Use C SDK for storage

**Phase 3-4 Issues:**
- Keep C SDK for events/state
- Use Swift SDK for storage only
- Partial migration is acceptable

**Phase 5-6 Issues:**
- Fix bugs before removal
- Extended testing period
- Gradual feature rollout

---

## Next Steps

### Immediate (Day 1)
1. ⏳ Add RouteProtocolKit to Xcode project
2. ⏳ Initialize Swift SDK in parallel
3. ⏳ Create migration adapter
4. ⏳ Test basic functionality

### This Week (Week 1)
1. ⏳ Complete parallel integration
2. ⏳ Migrate storage layer
3. ⏳ Test conversation/message loading
4. ⏳ Reach Checkpoint 1

### Next Week (Week 2)
1. ⏳ Migrate events
2. ⏳ Migrate state management
3. ⏳ Test real-time updates
4. ⏳ Reach Checkpoint 2

### Final Week (Week 3)
1. ⏳ Migrate security
2. ⏳ Remove C SDK
3. ⏳ Comprehensive testing
4. ⏳ Reach Checkpoint 3

---

## Conclusion

The Swift SDK migration is **well-scoped** and **lower risk** than expected due to:
- ✅ C SDK usage is well-encapsulated
- ✅ Clean abstraction layer exists
- ✅ Swift SDK is already complete
- ✅ Both Go routes use Go SDK (consistent)

**Expected outcome:**
- ✅ ~-2890 lines of code removed
- ✅ Pure Swift architecture
- ✅ Better maintainability
- ✅ Improved developer experience

**Timeline:** 3 weeks (15 days)  
**Risk Level:** Medium (manageable)  
**Confidence:** High ✅

**Ready to begin Phase 1!** 🚀
