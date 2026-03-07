//
//  TokenRefreshStrategy.swift
//  Rocket
//
//  Created as part of the token management refactoring.
//

import Foundation

/// Import required types for token refresh strategy

/// Strategy pattern for different token refresh behaviors
public protocol TokenRefreshStrategy {
    /// Determines if token refresh should be attempted for the given error and endpoint
    /// - Parameters:
    ///   - error: The error that occurred during the request
    ///   - endpoint: The endpoint that was requested
    ///   - attemptCount: Current attempt count for this request
    /// - Returns: True if token refresh should be attempted
    func shouldRefreshToken(
        for error: Error,
        endpoint: APIEndpoint,
        attemptCount: Int
    ) -> Bool
    
    /// Executes the token refresh operation
    /// - Parameters:
    ///   - tokenManager: The token manager to use for refresh
    ///   - completion: Completion handler with refresh result
    func executeRefresh(
        using tokenManager: TokenManaging,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    
    /// The priority of this strategy (higher values take precedence)
    var priority: Int { get }
}

/// Default implementation for common strategy behavior
public extension TokenRefreshStrategy {
    /// Default priority for strategies
    var priority: Int { return 100 }
}

/// Strategy that performs standard token refresh with configurable error types
public final class DefaultTokenRefreshStrategy: TokenRefreshStrategy {
    private let configuration: TokenRefreshConfiguration
    
    /// Initialize with configuration
    /// - Parameter configuration: The refresh configuration to use
    public init(configuration: TokenRefreshConfiguration = TokenRefreshConfiguration()) {
        self.configuration = configuration
    }
    
    public func shouldRefreshToken(
        for error: Error,
        endpoint: APIEndpoint,
        attemptCount: Int
    ) -> Bool {
        // Check if endpoint supports token refresh
        guard endpoint.supportsTokenRefresh else {
            return false
        }
        
        // Check if we haven't exceeded max refresh attempts
        guard attemptCount < configuration.maxRefreshAttempts else {
            return false
        }
        
        // Check if error type is configured for refresh
        guard let networkError = error as? NetworkError else {
            return false
        }
        
        return configuration.refreshableErrorTypes.contains(networkError.errorType)
    }
    
    public func executeRefresh(
        using tokenManager: TokenManaging,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await tokenManager.refreshToken()
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public var priority: Int { return 200 }
}

/// Strategy that never performs token refresh
public final class NoTokenRefreshStrategy: TokenRefreshStrategy {
    public init() {}
    
    public func shouldRefreshToken(
        for error: Error,
        endpoint: APIEndpoint,
        attemptCount: Int
    ) -> Bool {
        return false
    }
    
    public func executeRefresh(
        using tokenManager: TokenManaging,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.failure(TokenRefreshError.refreshNotSupported))
    }
    
    public var priority: Int { return 0 }
}

/// Strategy that performs conditional refresh based on custom logic
public final class ConditionalTokenRefreshStrategy: TokenRefreshStrategy {
    private let condition: (Error, APIEndpoint, Int) -> Bool
    private let refreshExecutor: (TokenManaging, @escaping (Result<Void, Error>) -> Void) -> Void
    private let strategyPriority: Int
    
    /// Initialize with custom condition and executor
    /// - Parameters:
    ///   - condition: Custom condition to determine if refresh should occur
    ///   - executor: Custom refresh execution logic
    ///   - priority: Priority of this strategy
    public init(
        condition: @escaping (Error, APIEndpoint, Int) -> Bool,
        executor: @escaping (TokenManaging, @escaping (Result<Void, Error>) -> Void) -> Void,
        priority: Int = 150
    ) {
        self.condition = condition
        self.refreshExecutor = executor
        self.strategyPriority = priority
    }
    
    public func shouldRefreshToken(
        for error: Error,
        endpoint: APIEndpoint,
        attemptCount: Int
    ) -> Bool {
        return condition(error, endpoint, attemptCount)
    }
    
    public func executeRefresh(
        using tokenManager: TokenManaging,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        refreshExecutor(tokenManager, completion)
    }
    
    public var priority: Int { return strategyPriority }
}

/// Errors specific to token refresh operations
public enum TokenRefreshError: Error, LocalizedError {
    case refreshNotSupported
    case maxRefreshAttemptsExceeded
    case concurrentRefreshInProgress
    case noRefreshTokenAvailable
    
    public var errorDescription: String? {
        switch self {
        case .refreshNotSupported:
            return "Token refresh is not supported for this endpoint"
        case .maxRefreshAttemptsExceeded:
            return "Maximum refresh attempts exceeded"
        case .concurrentRefreshInProgress:
            return "A refresh operation is already in progress"
        case .noRefreshTokenAvailable:
            return "No refresh token is available"
        }
    }
}
