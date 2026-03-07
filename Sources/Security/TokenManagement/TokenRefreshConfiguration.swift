//
//  TokenRefreshConfiguration.swift
//  Rocket
//
//  Created as part of token management refactoring.
//

import Foundation

/// Configuration for token refresh behavior
public struct TokenRefreshConfiguration {
    /// Maximum number of refresh attempts per request
    public var maxRefreshAttempts: Int
    
    /// Delay between refresh attempts in seconds
    public var refreshRetryDelay: TimeInterval
    
    /// Error types that should trigger token refresh
    public var refreshableErrorTypes: Set<NetworkError.ErrorType>
    
    /// Whether to allow concurrent refresh operations
    public var allowConcurrentRefresh: Bool
    
    /// Timeout for refresh operations
    public var refreshTimeout: TimeInterval
    
    /// Whether to enable exponential backoff for retries
    public var enableExponentialBackoff: Bool
    
    /// Maximum backoff delay when exponential backoff is enabled
    public var maxBackoffDelay: TimeInterval
    
    /// Creates a default configuration
    public init() {
        self.maxRefreshAttempts = 1
        self.refreshRetryDelay = 1.0
        self.refreshableErrorTypes = [.unauthenticated, .forbidden]
        self.allowConcurrentRefresh = false
        self.refreshTimeout = 30.0
        self.enableExponentialBackoff = false
        self.maxBackoffDelay = 10.0
    }
    
    /// Creates a configuration with custom settings
    /// - Parameters:
    ///   - maxRefreshAttempts: Maximum refresh attempts per request
    ///   - refreshRetryDelay: Delay between attempts in seconds
    ///   - refreshableErrorTypes: Error types that trigger refresh
    ///   - allowConcurrentRefresh: Allow concurrent refresh operations
    ///   - refreshTimeout: Timeout for refresh operations
    ///   - enableExponentialBackoff: Enable exponential backoff
    ///   - maxBackoffDelay: Maximum backoff delay
    public init(
        maxRefreshAttempts: Int = 1,
        refreshRetryDelay: TimeInterval = 1.0,
        refreshableErrorTypes: Set<NetworkError.ErrorType> = [.unauthenticated, .forbidden],
        allowConcurrentRefresh: Bool = false,
        refreshTimeout: TimeInterval = 30.0,
        enableExponentialBackoff: Bool = false,
        maxBackoffDelay: TimeInterval = 10.0
    ) {
        self.maxRefreshAttempts = maxRefreshAttempts
        self.refreshRetryDelay = refreshRetryDelay
        self.refreshableErrorTypes = refreshableErrorTypes
        self.allowConcurrentRefresh = allowConcurrentRefresh
        self.refreshTimeout = refreshTimeout
        self.enableExponentialBackoff = enableExponentialBackoff
        self.maxBackoffDelay = maxBackoffDelay
    }
    
    /// Calculates delay for given attempt number
    /// - Parameter attempt: Current attempt number (0-based)
    /// - Returns: Delay in seconds
    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        guard enableExponentialBackoff else {
            return refreshRetryDelay
        }
        
        let delay = refreshRetryDelay * pow(2.0, Double(attempt))
        return min(delay, maxBackoffDelay)
    }
}
