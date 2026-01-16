# Phase 2: Storage Migration Analysis

## Current Storage Architecture

### GRDB Schema (from `GRDBModels.swift`)

**Tables:**
1. **routes** - Route metadata
2. **conversations** - Chat conversations
3. **messages** - Chat messages
4. **participants** - Conversation participants
5. **messageReactions** - Message reactions (emoji)
6. **contacts** - Contact information
7. **attachments** - File attachments

### Key Columns

**conversations:**
```swift
- encryptedID (PK)
- encryptedRouteID (FK → routes)
- encryptedTitle
- typeRaw (int)
- encryptedLastMessagePreview
- lastMessageTimestamp
- unreadCount
- archived, muted, hasCustomName (booleans)
```

**messages:**
```swift
- encryptedID (PK)
- encryptedConversationID (FK → conversations)
- encryptedRouteID (FK → routes)
- encryptedSenderID
- encryptedSenderName
- encryptedText
- timestamp
- isOutgoing
- statusRaw (int)
- encryptedReplyToMessageID
- replyToPreview
```

### Current Access Patterns

**1. Direct GRDB Queries:**
```swift
// RouteProtocolEngine
func listConversationsGRDB(routeID: String?) -> [Conversation] {
    try dbQueue.read { db in
        Conversation.all().filter(...).fetchAll(db)
    }
}

func getMessagesGRDB(conversationID: String, limit: Int) -> [Message] {
    try dbQueue.read { db in
        Message.filter(...).order(...).limit(...).fetchAll(db)
    }
}
```

**2. Reactive UI Queries (SQLiteData):**
```swift
// ConversationsRootView
@FetchAll(
    SQLiteConversation
        .group(by: \.id)
        .join(SQLiteMessage.all) { $0.id.eq($1.conversationID) }
) private var conversationsWithLatest

// ChatDetailViewGRDB
@FetchAll(SQLiteMessage.order(by: \.timestamp)) 
private var allSqliteMessages
```

**3. Write Operations:**
```swift
try dbQueue.write { db in
    try conversation.insert(db)
    try message.update(db)
}
```

### Database Location

**C SDK:** `route_protocol.db` (Application Support)  
**Swift SDK:** `route_protocol_swift.db` (separate during migration)

---

## Migration Strategy

### Phase 2A: Schema Migration (Day 3)
**Goal:** Add app schema to Swift SDK

**Tasks:**
1. Update Swift SDK `StorageManager` with full schema
2. Add migration functions
3. Test schema creation

### Phase 2B: Data Migration (Day 3-4)
**Goal:** Copy existing data to Swift SDK

**Tasks:**
1. Create data copy helpers
2. Migrate conversations
3. Migrate messages
4. Migrate participants, reactions, attachments
5. Verify data integrity

### Phase 2C: Parallel Mode (Day 4)
**Goal:** Run both databases in parallel

**Tasks:**
1. Enable `.parallel` storage mode in adapter
2. Mirror writes to both databases
3. Test read consistency

### Phase 2D: Swift SDK Primary (Day 5)
**Goal:** Switch to Swift SDK as primary

**Tasks:**
1. Switch to `.parallelSwiftPrimary` mode
2. Update all read queries to use Swift SDK
3. Test thoroughly
4. Switch to `.swiftSDKOnly`

---

## Key Challenges

### 1. SQLiteData Integration
**Challenge:** App uses `@FetchAll` for reactive UI queries  
**Solution:** Swift SDK's `StorageManager` already uses GRDB's `DatabaseQueue`, so `@FetchAll` should work with it

### 2. Encryption
**Challenge:** All IDs are encrypted with `MetadataEncryptionManager`  
**Solution:** Keep using existing encryption manager (migrate in Phase 3)

### 3. Database Location
**Challenge:** Two separate databases during migration  
**Solution:** Use separate files, merge after migration complete

### 4. Write Mirroring
**Challenge:** Need to write to both databases during parallel mode  
**Solution:** Adapter intercepts writes and duplicates them

---

## Migration Adapter Updates

```swift
// Enable storage migration
migrationAdapter.strategies.storage = .parallel

// Intercept write operations
func saveConversation(_ conversation: Conversation) {
    // Write to C SDK (existing)
    cSDK.save(conversation)
    
    // Mirror to Swift SDK
    if strategies.storage == .parallel {
        swiftSDK.storage.write { db in
            try conversation.insert(db)
        }
    }
}
```

---

## Risk Assessment

### High Risk
1. **Data migration errors** - Could lose conversations/messages
   - Mitigation: Backup before migration, extensive testing
   
2. **Encryption key mismatch** - Data might not decrypt correctly
   - Mitigation: Use same encryption manager

### Medium Risk
1. **Performance during parallel mode** - Writing to 2 databases
   - Mitigation: Monitor performance, optimize if needed
   
2. **SQLiteData compatibility** - Reactive queries might break
   - Mitigation: Test early, have fallback

### Low Risk
1. **Schema differences** - Tables might not match
   - Mitigation: Copy exact schema from C SDK

---

## Success Criteria

### Phase 2A
- ✅ Swift SDK has full schema
- ✅ Schema matches C SDK exactly
- ✅ Swift SDK database creates successfully

### Phase 2B
- ✅ All conversations copied
- ✅ All messages copied
- ✅ Data integrity verified
- ✅ Encryption works correctly

### Phase 2C
- ✅ Writes go to both databases
- ✅ Reads consistent between databases
- ✅ No data loss

### Phase 2D
- ✅ All reads from Swift SDK
- ✅ UI updates work
- ✅ Performance acceptable
- ✅ Can switch to `.swiftSDKOnly`

---

## Next Steps

1. ✅ Understand current schema (DONE)
2. ⏳ Update Swift SDK with app schema
3. ⏳ Create data migration helpers
4. ⏳ Test schema migration
5. ⏳ Copy data from C SDK to Swift SDK
6. ⏳ Enable parallel mode
7. ⏳ Test thoroughly
8. ⏳ Switch to Swift SDK primary

---

**Status:** Analysis complete ✅  
**Ready to proceed with implementation!** 🚀
