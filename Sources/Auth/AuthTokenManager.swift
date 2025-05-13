//
//  AuthTokenManager.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation
import Security

/// Implementation of TokenManaging that handles token refresh and storage
public class AuthTokenManager: TokenManaging {
    private let tokenStorage: TokenStorage
    private let apiClient: AuthAPIClient

    /// Initialize with a token storage and API client
    /// - Parameters:
    ///   - tokenStorage: The storage for tokens
    ///   - apiClient: The API client for refreshing tokens
    public init(tokenStorage: TokenStorage, apiClient: AuthAPIClient) {
        self.tokenStorage = tokenStorage
        self.apiClient = apiClient
    }

    /// Get the current access token
    /// - Returns: The current access token if available
    public func currentToken() -> String? {
        return tokenStorage.getAccessToken()
    }

    /// Refresh the authentication token asynchronously
    /// - Throws: NetworkError if refresh fails
    public func refreshToken() async throws {
        guard let refreshToken = tokenStorage.getRefreshToken() else {
            throw NetworkError.unauthenticated
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.refreshToken { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Get the access token, refreshing if needed
    /// - Parameter completion: Completion handler with the result
    public func getAccessToken(completion: @escaping (Result<String, NetworkError>) -> Void) {
        if let accessToken = tokenStorage.getAccessToken() {
            // Return existing token if available
            completion(.success(accessToken))
            return
        }

        // No access token, attempt to refresh
        guard tokenStorage.getRefreshToken() != nil else {
            // No refresh token either
            completion(.failure(NetworkError.unauthenticated))
            return
        }

        // Refresh the token
        refreshToken { result in
            switch result {
            case .success:
                // Token refreshed successfully, get the new access token
                if let newAccessToken = self.tokenStorage.getAccessToken() {
                    completion(.success(newAccessToken))
                } else {
                    // This should not happen, but just in case
                    completion(.failure(NetworkError.unknownError))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Refresh the token using the refresh token
    /// - Parameter completion: Completion handler with the result
    public func refreshToken(completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let refreshToken = tokenStorage.getRefreshToken() else {
            completion(.failure(NetworkError.unauthenticated))
            return
        }

        apiClient.refreshTokens(refreshToken: refreshToken) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let (accessToken, refreshToken)):
                // Store the new tokens
                self.tokenStorage.storeAccessToken(accessToken)
                self.tokenStorage.storeRefreshToken(refreshToken)
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error as? NetworkError ?? NetworkError.unknownError))
            }
        }
    }

    /// Clear all stored tokens
    public func clearTokens() {
        tokenStorage.storeAccessToken(nil)
        tokenStorage.storeRefreshToken(nil)
    }
}

/// Protocol for API client that can refresh tokens
public protocol AuthAPIClient {
    /// Refresh tokens using a refresh token
    /// - Parameters:
    ///   - refreshToken: The refresh token to use
    ///   - completion: Completion handler with the result
    func refreshTokens(
        refreshToken: String, completion: @escaping (Result<(String, String), Error>) -> Void)
}
