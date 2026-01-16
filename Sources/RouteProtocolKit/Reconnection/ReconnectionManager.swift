import Foundation

/// Reconnection manager (Actor-based, thread-safe)
public actor ReconnectionManager {
    // MARK: - Configuration
    
    private var routeConfigs: [String: ReconnectionConfig] = [:]
    private var routeAttempts: [String: ReconnectionAttemptInfo] = [:]
    
    private struct ReconnectionAttemptInfo {
        var attempt: Int
        var lastAttemptTimestamp: Date
        var isReconnecting: Bool
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Configuration
    
    /// Configure reconnection for a route
    public func configure(routeID: String, config: ReconnectionConfig) {
        routeConfigs[routeID] = config
    }
    
    /// Get reconnection config for a route
    public func getConfig(routeID: String) -> ReconnectionConfig {
        routeConfigs[routeID] ?? .default
    }
    
    // MARK: - Reconnection Logic
    
    /// Trigger reconnection for a route
    public func triggerReconnection(routeID: String) throws -> TimeInterval {
        let config = getConfig(routeID: routeID)
        
        guard config.enabled else {
            throw RouteProtocolError.reconnectionDisabled
        }
        
        // Get or create attempt info
        var info = routeAttempts[routeID] ?? ReconnectionAttemptInfo(
            attempt: 0,
            lastAttemptTimestamp: Date.distantPast,
            isReconnecting: false
        )
        
        // Check if already reconnecting
        guard !info.isReconnecting else {
            throw RouteProtocolError.reconnectionInProgress
        }
        
        // Increment attempt
        info.attempt += 1
        
        // Check max attempts
        guard info.attempt <= config.maxAttempts else {
            routeAttempts.removeValue(forKey: routeID)
            throw RouteProtocolError.maxReconnectionAttemptsReached
        }
        
        // Calculate delay
        let delay = calculateDelay(
            attempt: info.attempt,
            config: config
        )
        
        // Update state
        info.isReconnecting = true
        info.lastAttemptTimestamp = Date()
        routeAttempts[routeID] = info
        
        return delay
    }
    
    /// Reset reconnection state (after successful connection)
    public func reset(routeID: String) {
        routeAttempts.removeValue(forKey: routeID)
    }
    
    /// Mark reconnection as complete
    public func completeReconnection(routeID: String, success: Bool) {
        if success {
            // Reset on success
            routeAttempts.removeValue(forKey: routeID)
        } else {
            // Mark as not reconnecting to allow next attempt
            if var info = routeAttempts[routeID] {
                info.isReconnecting = false
                routeAttempts[routeID] = info
            }
        }
    }
    
    /// Get current attempt number
    public func getCurrentAttempt(routeID: String) -> Int {
        routeAttempts[routeID]?.attempt ?? 0
    }
    
    /// Check if can reconnect
    public func canReconnect(routeID: String) -> Bool {
        let config = getConfig(routeID: routeID)
        guard config.enabled else { return false }
        
        let currentAttempt = getCurrentAttempt(routeID: routeID)
        return currentAttempt < config.maxAttempts
    }
    
    /// Check if currently reconnecting
    public func isReconnecting(routeID: String) -> Bool {
        routeAttempts[routeID]?.isReconnecting ?? false
    }
    
    // MARK: - Delay Calculation
    
    private func calculateDelay(
        attempt: Int,
        config: ReconnectionConfig
    ) -> TimeInterval {
        let delay = config.initialDelaySeconds * pow(config.backoffMultiplier, Double(attempt - 1))
        return min(delay, config.maxDelaySeconds)
    }
    
    /// Get next reconnection delay
    public func getNextDelay(routeID: String) -> TimeInterval {
        let config = getConfig(routeID: routeID)
        let currentAttempt = getCurrentAttempt(routeID: routeID)
        return calculateDelay(attempt: currentAttempt + 1, config: config)
    }
}

/// Retry manager for operations (Actor-based, thread-safe)
public actor RetryManager {
    // MARK: - State
    
    private var operationRetries: [String: RetryInfo] = [:]
    
    private struct RetryInfo {
        var attempt: Int
        var lastAttemptTimestamp: Date
        var policy: RetryPolicy
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Retry Logic
    
    /// Check if should retry operation
    public func shouldRetry(
        operationID: String,
        policy: RetryPolicy = .default
    ) -> Bool {
        let info = operationRetries[operationID] ?? RetryInfo(
            attempt: 0,
            lastAttemptTimestamp: Date.distantPast,
            policy: policy
        )
        
        return info.attempt < policy.maxAttempts
    }
    
    /// Record retry attempt
    public func recordAttempt(
        operationID: String,
        policy: RetryPolicy = .default
    ) throws -> TimeInterval {
        var info = operationRetries[operationID] ?? RetryInfo(
            attempt: 0,
            lastAttemptTimestamp: Date.distantPast,
            policy: policy
        )
        
        info.attempt += 1
        
        guard info.attempt <= policy.maxAttempts else {
            operationRetries.removeValue(forKey: operationID)
            throw RouteProtocolError.maxRetryAttemptsReached
        }
        
        info.lastAttemptTimestamp = Date()
        operationRetries[operationID] = info
        
        return calculateDelay(attempt: info.attempt, policy: policy)
    }
    
    /// Reset retry state (after success)
    public func reset(operationID: String) {
        operationRetries.removeValue(forKey: operationID)
    }
    
    /// Get current attempt number
    public func getCurrentAttempt(operationID: String) -> Int {
        operationRetries[operationID]?.attempt ?? 0
    }
    
    // MARK: - Delay Calculation
    
    private func calculateDelay(
        attempt: Int,
        policy: RetryPolicy
    ) -> TimeInterval {
        let delay = policy.initialDelaySeconds * pow(policy.backoffMultiplier, Double(attempt - 1))
        return min(delay, policy.maxDelaySeconds)
    }
    
    /// Execute operation with retry
    public func executeWithRetry<T>(
        operationID: String,
        policy: RetryPolicy = .default,
        operation: () async throws -> T
    ) async throws -> T {
        reset(operationID: operationID)
        
        while true {
            do {
                let result = try await operation()
                reset(operationID: operationID)
                return result
            } catch {
                guard shouldRetry(operationID: operationID, policy: policy) else {
                    throw error
                }
                
                let delay = try recordAttempt(operationID: operationID, policy: policy)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}
