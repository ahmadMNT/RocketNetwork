//
//  TokenManager.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for managing authentication tokens
public protocol TokenManaging {
    /// Get the current access token if available
    /// - Returns: The current token or nil if not available
    func currentToken() -> String?
    
    /// Refresh the authentication token
    /// - Throws: NetworkError if token refresh fails
    func refreshToken() async throws
}

/// Simple in-memory implementation of TokenManaging for testing
public class SimpleTokenManager: TokenManaging {
    private var token: String?
    private var refreshCallback: () async throws -> String
    
    /// Initialize with an optional token and a refresh callback
    /// - Parameters:
    ///   - initialToken: Optional initial token
    ///   - refreshCallback: Async callback to refresh token
    public init(initialToken: String? = nil, refreshCallback: @escaping () async throws -> String) {
        self.token = initialToken
        self.refreshCallback = refreshCallback
    }
    
    public func currentToken() -> String? {
        return token
    }
    
    public func refreshToken() async throws {
        do {
            token = try await refreshCallback()
        } catch {
            // Convert any errors to NetworkError
            if let networkError = error as? NetworkError {
                throw networkError
            } else {
                throw NetworkError.serverMessage(message: "Token refresh failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Set a new token
    /// - Parameter newToken: The token to set
    public func setToken(_ newToken: String?) {
        token = newToken
    }
} 
