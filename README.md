# RouteProtocolKit - Swift SDK

Modern Swift SDK for the Route Protocol, replacing the C SDK with native Swift implementation.

## Features

- ✅ **GRDB Storage** - Fast, reliable SQLite database with iOS File Protection
- ✅ **Secure Enclave** - Hardware-backed cryptographic keys (P256 signing & key agreement)
- ✅ **Keychain** - Secure credential storage with device-only access
- ✅ **Actor-based Concurrency** - Thread-safe state management using Swift actors
- ✅ **Event Queue** - Automatic event queuing and replay on reconnection
- ✅ **Reconnection Management** - Exponential backoff with configurable policies
- ✅ **Retry Logic** - Built-in retry for failed operations
- ✅ **Type-Safe API** - Full Swift type safety with async/await

## Architecture

```
┌─────────────────────────────────────────┐
│       RouteProtocolSDK (Swift)          │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Storage (GRDB + File Protection) │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Security (Secure Enclave +       │  │
│  │            Keychain)               │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  State Management (Actor)         │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Event Queue (Actor)              │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Reconnection (Actor)             │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                 │
                 │ XCFramework Bridge
                 ▼
┌─────────────────────────────────────────┐
│    Go Routes (Discord, WhatsApp, etc)   │
└─────────────────────────────────────────┘
```

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/RouteProtocolKit.git", from: "1.0.0")
]
```

### Xcode

Add package via File → Add Packages → enter the repository URL.

## Quick Start

```swift
import RouteProtocolKit

// 1. Create SDK instance
let sdk = try await RouteProtocolSDK.create()

// 2. Register a route
let discordRoute = DiscordRoute(routeID: "discord_1")
try await sdk.registerRoute(discordRoute)

// 3. Connect
try await sdk.connectRoute(routeID: "discord_1")

// 4. Send message
let message = try await sdk.sendMessage(
    routeID: "discord_1",
    conversationID: "conversation_123",
    text: "Hello!"
)

// 5. Get conversations
let conversations = try await sdk.getConversations(routeID: "discord_1")
```

## Implementing a Route

Implement the `RouteProtocol`:

```swift
public final class MyRoute: RouteProtocol {
    public var platform: String { "myplatform" }
    public var routeID: String { get async { _routeID } }
    public var displayName: String { get async { "My Platform" } }
    
    public func authenticate() async throws -> [String: String] {
        // Your auth implementation
    }
    
    public func connect() async throws {
        // Your connection implementation
    }
    
    public func sendMessage(
        conversationID: String,
        text: String,
        replyToMessageID: String?
    ) async throws -> Message {
        // Your send message implementation
    }
    
    // ... implement other methods
}
```

## Storage

The SDK uses **GRDB** (not SwiftData) for reliable, fast SQLite access:

```swift
// Read from database
let messages = try await sdk.getMessages(conversationID: "123", limit: 50)

// Automatic File Protection (.complete)
// Database is encrypted when device is locked
```

## Security

### Secure Enclave Keys

All cryptographic keys are stored in the **Secure Enclave** (hardware-backed):

```swift
let security = SecurityManager()

// Get identity key (P256 signing)
let identityKey = try security.getIdentityKey()

// Create ephemeral key (per-conversation)
let ephemeralKey = try security.createEphemeralKey(conversationID: "123")

// Keys are device-locked and never exported
```

### Keychain Credentials

Route tokens and credentials are stored in the **Keychain**:

```swift
// Save token
try KeychainManager.saveRouteToken("token_abc", routeID: "discord_1")

// Load token
let token = try KeychainManager.loadRouteToken(routeID: "discord_1")

// Access: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

## Event Queue

Events are automatically queued when route is disconnected:

```swift
// Events are queued if route not connected
try await sdk.queueEvent(event)

// Processed automatically when route reconnects
let processedCount = try await sdk.processQueuedEvents(routeID: "discord_1")
```

## Reconnection

Automatic reconnection with exponential backoff:

```swift
// Configure reconnection
await sdk.reconnection.configure(
    routeID: "discord_1",
    config: ReconnectionConfig(
        enabled: true,
        maxAttempts: 5,
        initialDelaySeconds: 1.0,
        maxDelaySeconds: 60.0,
        backoffMultiplier: 2.0
    )
)

// Reconnection happens automatically on disconnect
```

## State Management

Thread-safe state tracking:

```swift
// Get route state
let state = await sdk.getRouteState(routeID: "discord_1")

// Check if connected
let isConnected = await sdk.isRouteConnected(routeID: "discord_1")

// Stream state changes
for await state in sdk.stateManager.stateChanges(for: "discord_1") {
    print("State changed to: \(state)")
}
```

## Retry Logic

Built-in retry with exponential backoff:

```swift
// Execute with retry
let result = try await sdk.retry.executeWithRetry(
    operationID: "my_operation",
    policy: .default
) {
    try await myOperation()
}
```

## Testing

Run tests:

```bash
swift test
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## License

[Your License]

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## See Also

- [Architecture Documentation](../SWIFT_SDK_ARCHITECTURE.md)
- [Example Implementation](Examples/DiscordRouteExample.swift)
- [API Reference](https://docs.reroute.app/swift-sdk)
