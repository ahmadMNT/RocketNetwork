//
//  TokenRefreshUsage.swift
//  RocketNetwork
//
//  Usage examples for the new token refresh system
//

import Foundation

/// Example of how to use the new token refresh system
public class TokenRefreshUsage {
    
    /// Example 1: Using default token manager (existing behavior)
    public func createNetworkManagerWithDefaultRefresh(
        tokenManager: TokenManaging,
        logger: NetworkLogger
    ) -> NetworkManager {
        // Uses default token manager for refresh - no changes needed
        return NetworkManager(
            tokenManager: tokenManager,
            logger: logger
        )
    }
    
    /// Example 2: Using custom token refresh handler
    public func createNetworkManagerWithCustomRefresh(
        tokenManager: TokenManaging,
        logger: NetworkLogger,
        apiClient: APIClient,
        tokenStorage: CustomTokenStorage
    ) -> NetworkManager {
        // Create custom refresh handler
        let customRefreshHandler = CustomTokenRefreshHandler(
            apiClient: apiClient,
            tokenStorage: tokenStorage
        )
        
        // Use custom handler for token refresh
        return NetworkManager(
            tokenManager: tokenManager,
            logger: logger,
            tokenRefreshHandler: customRefreshHandler
        )
    }
    
    /// Example 3: Creating a custom refresh handler with your own API
    public func createCustomRefreshHandler() -> TokenRefreshHandler {
        return MyCustomRefreshHandler()
    }
}

/// Example of implementing your own custom refresh handler
public class MyCustomRefreshHandler: TokenRefreshHandler {
    
    public init() {}
    
    /// Implement your custom refresh token API call here
    public func refreshToken() async throws {
        // Example: Call your refresh token API
        // let response = try await myAPIService.refreshToken()
        // saveNewTokens(response.accessToken, response.refreshToken)
        
        // For demonstration, we'll just throw an error
        throw TokenRefreshError.networkError(URLError(.notConnectedToInternet))
    }
}

/// Example of how to configure error types for token refresh
public extension NetworkManager {
    /// Configure which error types should trigger token refresh
    func configureTokenRefreshErrors() {
        self.tokenRefreshErrorTypes = [
            .unauthenticated,
            .forbidden
            // Add your custom error types here if needed
        ]
    }
}
