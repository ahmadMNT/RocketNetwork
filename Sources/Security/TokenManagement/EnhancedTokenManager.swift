//
//  EnhancedTokenManager.swift
//  Rocket
//
//  Created as part of token management refactoring.
//

import Foundation

/// Enhanced token manager following SOLID principles with error preservation
public final class EnhancedTokenManager: TokenManaging {
    // MARK: - Properties
    
    private let tokenStorage: TokenStorage
    private let refreshCoordinator: TokenRefreshCoordinator
    private let configuration: TokenRefreshConfiguration
    
    // Thread-safe token caching
    private var cachedToken: String?
    private var lastTokenRefresh: Date?
    private let tokenLock = NSLock()
    
    // MARK: - Initialization
    
    /// Initialize enhanced token manager
    /// - Parameters:
    ///   - tokenStorage: Storage for tokens
    ///   - refreshCoordinator: Coordinator for refresh operations
    ///   - configuration: Refresh configuration
    public init(
        tokenStorage: TokenStorage,
        refreshCoordinator: TokenRefreshCoordinator,
        configuration: TokenRefreshConfiguration = TokenRefreshConfiguration()
    ) {
        self.tokenStorage = tokenStorage
        self.refreshCoordinator = refreshCoordinator
        self.configuration = configuration
        
        // Cache initial token if available
        self.cachedToken = tokenStorage.getAccessToken()
    }
    
    /// Initialize with custom refresh strategy
    /// - Parameters:
    ///   - tokenStorage: Storage for tokens
    ///   - strategies: Array of refresh strategies
    ///   - configuration: Refresh configuration
    public convenience init(
        tokenStorage: TokenStorage,
        strategies: [TokenRefreshStrategy],
        configuration: TokenRefreshConfiguration = TokenRefreshConfiguration()
    ) {
        let coordinator = TokenRefreshCoordinator(
            strategies: strategies,
            configuration: configuration,
            tokenManager: Self(tokenStorage: tokenStorage, configuration: configuration)
        )
        self.init(tokenStorage: tokenStorage, refreshCoordinator: coordinator, configuration: configuration)
    }
    
    // MARK: - TokenManaging Implementation
    
    /// Get the current access token
    /// - Returns: The current access token if available
    public func currentToken() -> String? {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        
        // Return cached token if available and not too old
        if let token = cachedToken,
           let lastRefresh = lastTokenRefresh,
           Date().timeIntervalSince(lastRefresh) < configuration.refreshTimeout {
            return token
        }
        
        // Try to get from storage
        let storedToken = tokenStorage.getAccessToken()
        if storedToken != nil {
            cachedToken = storedToken
            lastTokenRefresh = Date()
        }
        
        return storedToken
    }
    
    /// Refresh the authentication token
    /// - Throws: NetworkError if refresh fails
    public func refreshToken() async throws {
        // Check if we have a refresh token
        guard tokenStorage.getRefreshToken() != nil else {
            throw NetworkError.unauthenticated(
                error: DefaultErrorModel(message: "No refresh token available")
            )
        }
        
        // Perform refresh using coordinator
        let requestId = TokenRefreshCoordinator.generateRequestId()
        
        return try await withCheckedThrowingContinuation { continuation in
            refreshCoordinator.attemptRefresh(
                for: NetworkError.unauthenticated(
                    error: DefaultErrorModel(message: "Token refresh required")
                ),
                endpoint: createRefreshEndpoint(),
                requestId: requestId
            ) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    // Convert to appropriate NetworkError
                    let networkError: NetworkError
                    switch error {
                    case .refreshNotSupported:
                        networkError = .unauthenticated(
                            error: DefaultErrorModel(message: "Token refresh not supported")
                        )
                    case .maxRefreshAttemptsExceeded:
                        networkError = .maxRetriesExceeded
                    case .concurrentRefreshInProgress:
                        networkError = .serverMessage(message: "Refresh operation in progress")
                    case .noRefreshTokenAvailable:
                        networkError = .unauthenticated(
                            error: DefaultErrorModel(message: "No refresh token available")
                        )
                    }
                    continuation.resume(throwing: networkError)
                }
            }
        }
    }
    
    // MARK: - Enhanced Methods
    
    /// Get token with automatic refresh and error preservation
    /// - Parameters:
    ///   - endpoint: The endpoint that requires the token
    ///   - originalError: Original error that triggered refresh (if any)
    /// - Returns: Valid access token
    /// - Throws: Original error if refresh fails, NetworkError for other issues
    public func getValidToken(
        for endpoint: APIEndpoint,
        originalError: Error? = nil
    ) async throws -> String {
        // Try to get current token first
        if let token = currentToken() {
            return token
        }
        
        // No token available, try to refresh
        do {
            try await refreshToken()
            
            // Return the refreshed token
            guard let token = currentToken() else {
                throw originalError ?? NetworkError.unauthenticated(
                    error: DefaultErrorModel(message: "No token available after refresh")
                )
            }
            
            return token
        } catch {
            // Preserve original error if provided
            if let originalError = originalError {
                throw originalError
            }
            
            // Throw the refresh error
            throw error
        }
    }
    
    /// Attempt refresh with context preservation
    /// - Parameters:
    ///   - error: The error that triggered refresh
    ///   - endpoint: The endpoint that was requested
    ///   - completion: Completion handler with result
    public func attemptRefreshWithContext(
        for error: Error,
        endpoint: APIEndpoint,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let requestId = TokenRefreshCoordinator.generateRequestId(for: endpoint, url: endpoint.baseURL)
        
        refreshCoordinator.attemptRefresh(
            for: error,
            endpoint: endpoint,
            requestId: requestId
        ) { [weak self] result in
            switch result {
            case .success:
                completion(.success(()))
                
            case .failure(let refreshError):
                // Preserve original error context
                let contextualError = TokenRefreshContextError(
                    originalError: error,
                    refreshError: refreshError,
                    endpoint: endpoint
                )
                completion(.failure(contextualError))
            }
        }
    }
    
    // MARK: - Token Management
    
    /// Set a new access token
    /// - Parameter token: The token to set
    public func setAccessToken(_ token: String?) {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        
        tokenStorage.storeAccessToken(token)
        cachedToken = token
        lastTokenRefresh = token != nil ? Date() : nil
    }
    
    /// Set a new refresh token
    /// - Parameter token: The refresh token to set
    public func setRefreshToken(_ token: String?) {
        tokenStorage.storeRefreshToken(token)
    }
    
    /// Clear all stored tokens
    public func clearAllTokens() {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        
        tokenStorage.storeAccessToken(nil)
        tokenStorage.storeRefreshToken(nil)
        cachedToken = nil
        lastTokenRefresh = nil
        refreshCoordinator.clearAllTracking()
    }
    
    // MARK: - Private Methods
    
    private func createRefreshEndpoint() -> APIEndpoint {
        // Create a simple endpoint for refresh operations
        struct RefreshEndpoint: APIEndpoint {
            var host: String { return "localhost" }
            var path: String { return "/refresh" }
            var method: HTTPMethod { return .post }
            var authenticationCredentials: AuthenticationCredentials { return .none }
            var supportsTokenRefresh: Bool { return false } // Prevent infinite recursion
        }
        
        return RefreshEndpoint()
    }
}

// MARK: - Token Refresh Context Error

/// Error that preserves both original and refresh error context
public struct TokenRefreshContextError: Error, LocalizedError {
    public let originalError: Error
    public let refreshError: TokenRefreshError
    public let endpoint: APIEndpoint
    
    public var errorDescription: String? {
        return "Token refresh failed for \(endpoint.path). Original: \(originalError.localizedDescription), Refresh: \(refreshError.localizedDescription)"
    }
    
    /// Get the original error that should be returned to the caller
    public var errorToReturn: Error {
        return originalError
    }
}
