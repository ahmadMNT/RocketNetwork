//
//  TokenRefreshCoordinator.swift
//  Rocket
//
//  Created as part of token management refactoring.
//

import Foundation

/// Coordinates token refresh operations and prevents infinite loops
public final class TokenRefreshCoordinator {
    // MARK: - Properties
    
    private let strategies: [TokenRefreshStrategy]
    private let configuration: TokenRefreshConfiguration
    private let tokenManager: TokenManaging
    
    // Thread-safe tracking of refresh attempts
    private var refreshAttempts: [String: Int] = [:]
    private let refreshQueue = DispatchQueue(label: "com.rocketnetwork.refresh", attributes: .concurrent)
    private var isRefreshing = false
    private let refreshLock = NSLock()
    
    // MARK: - Initialization
    
    /// Initialize coordinator with strategies and configuration
    /// - Parameters:
    ///   - strategies: Array of token refresh strategies (sorted by priority)
    ///   - configuration: Refresh configuration
    ///   - tokenManager: Token manager to use for refresh operations
    public init(
        strategies: [TokenRefreshStrategy],
        configuration: TokenRefreshConfiguration = TokenRefreshConfiguration(),
        tokenManager: TokenManaging
    ) {
        // Sort strategies by priority (highest first)
        self.strategies = strategies.sorted { $0.priority > $1.priority }
        self.configuration = configuration
        self.tokenManager = tokenManager
    }
    
    /// Initialize coordinator with default strategy
    /// - Parameters:
    ///   - configuration: Refresh configuration
    ///   - tokenManager: Token manager to use for refresh operations
    public convenience init(
        configuration: TokenRefreshConfiguration = TokenRefreshConfiguration(),
        tokenManager: TokenManaging
    ) {
        let defaultStrategy = DefaultTokenRefreshStrategy(configuration: configuration)
        self.init(strategies: [defaultStrategy], configuration: configuration, tokenManager: tokenManager)
    }
    
    // MARK: - Public Methods
    
    /// Attempts to refresh token for the given error and endpoint
    /// - Parameters:
    ///   - error: The error that occurred during the request
    ///   - endpoint: The endpoint that was requested
    ///   - requestId: Unique identifier for the request
    ///   - completion: Completion handler with result
    public func attemptRefresh(
        for error: Error,
        endpoint: APIEndpoint,
        requestId: String,
        completion: @escaping (Result<Void, TokenRefreshError>) -> Void
    ) {
        // Check if we should attempt refresh
        guard shouldAttemptRefresh(for: error, endpoint: endpoint, requestId: requestId) else {
            completion(.failure(.refreshNotSupported))
            return
        }
        
        // Handle concurrent refresh prevention
        guard configuration.allowConcurrentRefresh || !isRefreshing else {
            completion(.failure(.concurrentRefreshInProgress))
            return
        }
        
        // Find the first strategy that supports refresh for this error
        guard let strategy = strategies.first(where: { strategy in
            let attemptCount = getAttemptCount(for: requestId)
            return strategy.shouldRefreshToken(for: error, endpoint: endpoint, attemptCount: attemptCount)
        }) else {
            completion(.failure(.refreshNotSupported))
            return
        }
        
        // Increment attempt count
        incrementAttemptCount(for: requestId)
        
        // Set refreshing flag
        if !configuration.allowConcurrentRefresh {
            refreshLock.lock()
            isRefreshing = true
            refreshLock.unlock()
        }
        
        // Execute refresh with timeout
        executeRefreshWithTimeout(
            using: strategy,
            requestId: requestId,
            completion: completion
        )
    }
    
    /// Resets tracking for a specific request
    /// - Parameter requestId: The request ID to reset
    public func resetTracking(for requestId: String) {
        refreshQueue.async(flags: .barrier) {
            self.refreshAttempts.removeValue(forKey: requestId)
        }
    }
    
    /// Clears all tracking data
    public func clearAllTracking() {
        refreshQueue.async(flags: .barrier) {
            self.refreshAttempts.removeAll()
        }
        
        refreshLock.lock()
        isRefreshing = false
        refreshLock.unlock()
    }
    
    /// Gets current refresh status
    /// - Returns: True if a refresh operation is in progress
    public var isRefreshInProgress: Bool {
        refreshLock.lock()
        defer { refreshLock.unlock() }
        return isRefreshing
    }
    
    // MARK: - Private Methods
    
    private func shouldAttemptRefresh(
        for error: Error,
        endpoint: APIEndpoint,
        requestId: String
    ) -> Bool {
        let attemptCount = getAttemptCount(for: requestId)
        
        // Check if we've exceeded max attempts
        guard attemptCount < configuration.maxRefreshAttempts else {
            return false
        }
        
        // Check if any strategy supports refresh
        return strategies.contains { strategy in
            strategy.shouldRefreshToken(for: error, endpoint: endpoint, attemptCount: attemptCount)
        }
    }
    
    private func getAttemptCount(for requestId: String) -> Int {
        return refreshQueue.sync {
            return refreshAttempts[requestId] ?? 0
        }
    }
    
    private func incrementAttemptCount(for requestId: String) {
        refreshQueue.async(flags: .barrier) {
            let currentCount = self.refreshAttempts[requestId] ?? 0
            self.refreshAttempts[requestId] = currentCount + 1
        }
    }
    
    private func executeRefreshWithTimeout(
        using strategy: TokenRefreshStrategy,
        requestId: String,
        completion: @escaping (Result<Void, TokenRefreshError>) -> Void
    ) {
        // Create timeout task
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(configuration.refreshTimeout * 1_000_000_000))
            
            // Timeout reached
            await MainActor.run {
                if !Task.isCancelled {
                    completion(.failure(.maxRefreshAttemptsExceeded))
                }
            }
        }
        
        // Execute refresh
        strategy.executeRefresh(using: tokenManager) { [weak self] result in
            Task {
                timeoutTask.cancel()
                
                await MainActor.run {
                    switch result {
                    case .success:
                        // Reset tracking on success
                        self?.resetTracking(for: requestId)
                        completion(.success(()))
                        
                    case .failure(let error):
                        // Convert to TokenRefreshError if needed
                        let refreshError: TokenRefreshError
                        if let tokenError = error as? TokenRefreshError {
                            refreshError = tokenError
                        } else {
                            refreshError = .noRefreshTokenAvailable
                        }
                        
                        completion(.failure(refreshError))
                    }
                    
                    // Clear refreshing flag
                    if !(self?.configuration.allowConcurrentRefresh ?? true) {
                        self?.refreshLock.lock()
                        self?.isRefreshing = false
                        self?.refreshLock.unlock()
                    }
                }
            }
        }
    }
}

// MARK: - Request ID Generation

public extension TokenRefreshCoordinator {
    /// Generates a unique request ID for tracking
    /// - Parameters:
    ///   - endpoint: The endpoint being requested
    ///   - url: The request URL
    /// - Returns: Unique request identifier
    static func generateRequestId(for endpoint: APIEndpoint, url: URL) -> String {
        let timestamp = Date().timeIntervalSince1970
        let urlHash = url.absoluteString.hash
        let endpointHash = String(describing: type(of: endpoint)).hash
        return "\(timestamp)-\(urlHash)-\(endpointHash)"
    }
    
    /// Generates a simple request ID
    /// - Returns: Unique request identifier
    static func generateRequestId() -> String {
        return UUID().uuidString
    }
}
