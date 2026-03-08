//
//  CustomTokenRefreshHandler.swift
//  RocketNetwork
//
//  Example implementation of custom token refresh handler
//

import Foundation

/// Example implementation of TokenRefreshHandler for custom refresh token API
public class CustomTokenRefreshHandler: TokenRefreshHandler {
    
    private let apiClient: APIClient
    private let tokenStorage: CustomTokenStorage
    
    /// Initialize custom token refresh handler
    /// - Parameters:
    ///   - apiClient: API client for making refresh requests
    ///   - tokenStorage: Storage for saving refreshed tokens
    public init(apiClient: APIClient, tokenStorage: CustomTokenStorage) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
    }
    
    /// Refresh the authentication token using custom API
    /// - Throws: Error if refresh fails
    public func refreshToken() async throws {
        // Get current refresh token
        guard let refreshToken = tokenStorage.getRefreshToken() else {
            throw TokenRefreshError.noRefreshToken
        }
        
        // Call your custom refresh token API
        let refreshRequest = RefreshTokenRequest(refreshToken: refreshToken)
        let response = try await apiClient.refreshToken(refreshRequest)
        
        // Save new tokens
        tokenStorage.saveTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
    }
}

/// Example API client protocol for token refresh
public protocol APIClient {
    func refreshToken(_ request: RefreshTokenRequest) async throws -> RefreshTokenResponse
}

/// Example request model
public struct RefreshTokenRequest {
    public let refreshToken: String
    
    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

/// Example response model
public struct RefreshTokenResponse {
    public let accessToken: String
    public let refreshToken: String
    
    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

/// Example token storage protocol
public protocol CustomTokenStorage {
    func getRefreshToken() -> String?
    func saveTokens(accessToken: String, refreshToken: String)
}

/// Token refresh errors
public enum TokenRefreshError: Error {
    case noRefreshToken
    case invalidResponse
    case networkError(Error)
    
    public var localizedDescription: String {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidResponse:
            return "Invalid refresh token response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
