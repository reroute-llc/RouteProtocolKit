import Foundation

/// Route state manager (Actor-based, thread-safe)
public actor RouteStateManager {
    // MARK: - State Storage
    
    private var routeStates: [String: RouteStateInfo] = [:]
    private var stateChangeCallbacks: [(String, RouteState) -> Void] = []
    
    private struct RouteStateInfo {
        var state: RouteState
        var lastStateChangeTimestamp: Date
        var error: String?
        var errorTimestamp: Date?
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - State Management
    
    /// Set route state
    public func setState(routeID: String, state: RouteState) {
        let now = Date()
        
        if var existing = routeStates[routeID] {
            existing.state = state
            existing.lastStateChangeTimestamp = now
            existing.error = nil
            existing.errorTimestamp = nil
            routeStates[routeID] = existing
        } else {
            routeStates[routeID] = RouteStateInfo(
                state: state,
                lastStateChangeTimestamp: now,
                error: nil,
                errorTimestamp: nil
            )
        }
        
        // Notify callbacks
        notifyStateChange(routeID: routeID, state: state)
    }
    
    /// Get route state
    public func getState(routeID: String) -> RouteState {
        routeStates[routeID]?.state ?? .disconnected
    }
    
    /// Set route error
    public func setError(routeID: String, error: String) {
        let now = Date()
        
        if var existing = routeStates[routeID] {
            existing.state = .error
            existing.error = error
            existing.errorTimestamp = now
            existing.lastStateChangeTimestamp = now
            routeStates[routeID] = existing
        } else {
            routeStates[routeID] = RouteStateInfo(
                state: .error,
                lastStateChangeTimestamp: now,
                error: error,
                errorTimestamp: now
            )
        }
        
        // Notify callbacks
        notifyStateChange(routeID: routeID, state: .error)
    }
    
    /// Get route error
    public func getError(routeID: String) -> String? {
        routeStates[routeID]?.error
    }
    
    /// Get time since last state change
    public func getTimeSinceLastStateChange(routeID: String) -> TimeInterval {
        guard let info = routeStates[routeID] else {
            return 0
        }
        return Date().timeIntervalSince(info.lastStateChangeTimestamp)
    }
    
    /// Clear route state
    public func clearState(routeID: String) {
        routeStates.removeValue(forKey: routeID)
    }
    
    /// Get all route states
    public func getAllStates() -> [String: RouteState] {
        routeStates.mapValues { $0.state }
    }
    
    // MARK: - State Validation
    
    /// Check if route is in valid state for operation
    public func validateState(
        routeID: String,
        requiredState: RouteState
    ) throws {
        let currentState = getState(routeID: routeID)
        guard currentState == requiredState else {
            throw RouteProtocolError.invalidState(
                current: currentState.rawValue,
                required: requiredState.rawValue
            )
        }
    }
    
    /// Check if route is connected
    public func isConnected(routeID: String) -> Bool {
        getState(routeID: routeID) == .connected
    }
    
    /// Check if route is connecting
    public func isConnecting(routeID: String) -> Bool {
        let state = getState(routeID: routeID)
        return state == .connecting || state == .reconnecting
    }
    
    /// Check if route has error
    public func hasError(routeID: String) -> Bool {
        getState(routeID: routeID) == .error
    }
    
    // MARK: - Callbacks
    
    /// Register state change callback
    public func registerStateChangeCallback(
        _ callback: @escaping (String, RouteState) -> Void
    ) {
        stateChangeCallbacks.append(callback)
    }
    
    private func notifyStateChange(routeID: String, state: RouteState) {
        for callback in stateChangeCallbacks {
            callback(routeID, state)
        }
    }
}

// MARK: - AsyncSequence Support

extension RouteStateManager {
    /// Stream of state changes for a specific route
    public func stateChanges(for routeID: String) -> AsyncStream<RouteState> {
        AsyncStream { continuation in
            // Send current state
            continuation.yield(getState(routeID: routeID))
            
            // Register callback for future changes
            Task {
                await registerStateChangeCallback { id, state in
                    if id == routeID {
                        continuation.yield(state)
                    }
                }
            }
        }
    }
}
