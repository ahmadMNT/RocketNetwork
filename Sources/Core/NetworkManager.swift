//
//  NetworkManager.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation
import Security

/// Protocol defining network connectivity operations
public protocol NetworkConnectivityProvider {
    /// Check if network is reachable
    func isNetworkReachable() async -> Bool
}

/// Protocol defining core network service functionality
public protocol NetworkServiceProtocol {
    /// Performs a network request to the specified endpoint and returns decoded data
    /// - Parameter endpoint: The API endpoint to request
    /// - Returns: Result containing either the decoded data or an error
    func performRequest<T: Decodable>(to endpoint: APIEndpoint) async -> Result<T, NetworkError>
    
    /// Cancels all ongoing network requests
    func cancelAllRequests() async
    
    /// Check if network is reachable
    func isNetworkReachable() async -> Bool
}

/// Main implementation of the NetworkServiceProtocol
public final class NetworkManager: NetworkServiceProtocol, NetworkConnectivityProvider {
    private let session: URLSession
    private let tokenManager: TokenManaging
    private let logger: NetworkLogger
    private let responseProcessor: ResponseProcessorProtocol
    private let sslPinningStrategy: SSLPinningStrategy
    private let reachability: Reachability
    private var hasAttemptedTokenRefresh = false
    
    // Configuration for token refresh error types
    public var tokenRefreshErrorTypes: [NetworkError.ErrorType] = [.unauthenticated, .forbidden]
    
    // File uploader is optional and can be added if needed
    // private let fileUploader: FileUploader
    
    /// Initialize a NetworkManager with custom components
    /// - Parameters:
    ///   - session: URLSession to use for network requests
    ///   - tokenManager: Manager for authentication tokens
    ///   - logger: Logger for network activity
    ///   - responseProcessor: Processor for API responses
    ///   - sslPinningStrategy: Strategy for SSL certificate pinning
    ///   - reachability: Reachability checker for network connectivity
    public init(
        session: URLSession = .shared,
        tokenManager: TokenManaging,
        logger: NetworkLogger,
        responseProcessor: ResponseProcessorProtocol = DefaultResponseProcessor(),
        sslPinningStrategy: SSLPinningStrategy = SSLPinningDisabledStrategy(),
        reachability: Reachability = try! Reachability()
    ) {
        self.sslPinningStrategy = sslPinningStrategy
        self.reachability = reachability
        
        if let delegate = sslPinningStrategy.createSessionDelegate() {
            let config = URLSessionConfiguration.default
            self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        } else {
            self.session = session
        }
        
        self.tokenManager = tokenManager
        self.logger = logger
        self.responseProcessor = responseProcessor
        
        // Start monitoring network connectivity
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
    }
    
    /// Deinitializer to clean up resources
    deinit {
        // Stop monitoring when the NetworkManager is deallocated
        reachability.stopNotifier()
    }
    
    public func performRequest<T: Decodable>(to endpoint: APIEndpoint) async -> Result<
        T, NetworkError
    > {
        // Check for network connectivity before attempting the request
        if await !isNetworkReachable() {
            logger.logError(NetworkError.noInternetConnection)
            return .failure(NetworkError.noInternetConnection)
        }
        
        // Reset token refresh flag for new request
        hasAttemptedTokenRefresh = false
        
        // Implementing the retry logic
        return await performRequestWithRetry(to: endpoint, currentAttempt: 0)
    }
    
    /// Internal method handling the retry logic for requests
    /// - Parameters:
    ///   - endpoint: The API endpoint to request
    ///   - currentAttempt: The current retry attempt number
    /// - Returns: Result containing either the decoded data or an error
    private func performRequestWithRetry<T: Decodable>(
        to endpoint: APIEndpoint,
        currentAttempt: Int
    ) async -> Result<T, NetworkError> {
        // Check if we've exceeded retry count
        guard currentAttempt <= endpoint.retryCount else {
            return .failure(NetworkError.maxRetriesExceeded)
        }
        
        do {
            let request = endpoint.buildURLRequest()
            logger.logRequest(request)
            
            let (data, response) = try await session.data(for: request)
            logger.logResponse(response, data: data)
            
            let result: Result<T, NetworkError> = try responseProcessor.process(data: data, response: response)
            
            switch result {
            case .success(let success):
                return .success(success)
            case .failure(let failure):
                return await handleRequestFailure(failure, endpoint: endpoint, currentAttempt: currentAttempt)
            }
        } catch let error as NetworkError {
            return await handleRequestFailure(error, endpoint: endpoint, currentAttempt: currentAttempt)
        } catch {
            return .failure(mapError(error))
        }
    }
    
    /// Handles request failures and determines retry strategy
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - endpoint: The API endpoint that was requested
    ///   - currentAttempt: The current retry attempt number
    /// - Returns: Result containing either the decoded data or an error
    private func handleRequestFailure<T: Decodable>(
        _ error: NetworkError,
        endpoint: APIEndpoint,
        currentAttempt: Int
    ) async -> Result<T, NetworkError> {
        // Check if we should retry with token refresh
        if shouldRetryWithTokenRefresh(error: error, endpoint: endpoint, attempt: currentAttempt) {
            hasAttemptedTokenRefresh = true
            do {
                
                try await tokenManager.refreshToken()
                return await performRequestWithRetry(
                    to: endpoint,
                    currentAttempt: currentAttempt + 1
                )
            } catch _ {
                // return the original error
                return .failure(error)
            }
        }
        
        // Check for network connectivity before retrying
        if await !isNetworkReachable() {
            logger.logError(NetworkError.noInternetConnection)
            return .failure(NetworkError.noInternetConnection)
        }
        
        // Check if we should retry for other reasons
        if shouldRetry(attempt: currentAttempt, maxRetries: endpoint.retryCount) {
            // Wait a second before retrying
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))
            return await performRequestWithRetry(
                to: endpoint,
                currentAttempt: currentAttempt + 1
            )
        } else {
            return .failure(error)
        }
    }
    
    public func cancelAllRequests() async {
        await session.invalidateAndCancel()
    }
    
    public func isNetworkReachable() async -> Bool {
        return await reachability.isConnectedToNetwork
    }
    
    private func shouldRetryWithTokenRefresh(error: Error, endpoint: APIEndpoint, attempt: Int) -> Bool {
        guard let networkError = error as? NetworkError else {
            print("🔍 Error is not NetworkError: \(type(of: error))")
            return false
        }
        
        let shouldRetry = endpoint.supportsTokenRefresh &&
        tokenRefreshErrorTypes.contains(networkError.errorType) &&
        !hasAttemptedTokenRefresh &&
        attempt == 0
        
        if shouldRetry {
            hasAttemptedTokenRefresh = true
        }
        
        return shouldRetry
    }
    
    private func shouldRetry(attempt: Int, maxRetries: Int) -> Bool {
        return attempt < maxRetries
    }
    
    private func mapError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternetConnection
            case .timedOut:
                return .requestTimedOut
            case .cancelled:
                return .canceled
            default:
                break
            }
        }
        
        if let networkError = error as? NetworkError {
            return networkError
        }
        return .unknownError
    }
}

// MARK: - Factory Methods

extension NetworkManager {
    /// Creates a NetworkManager with SSL pinning enabled
    /// - Parameters:
    ///   - domain: The domain to pin certificates for
    ///   - certificateNames: Names of certificate files in the bundle
    ///   - tokenManager: The token manager instance
    ///   - logger: The network logger instance
    /// - Returns: A configured NetworkManager instance with SSL pinning
    public static func withSSLPinning(
        domain: String,
        certificateNames: [String],
        tokenManager: TokenManaging,
        logger: NetworkLogger
    ) -> NetworkManager {
        let sslPinningStrategy = SSLPinningEnabledStrategy(
            domain: domain,
            certificateNames: certificateNames
        )
        return NetworkManager(
            tokenManager: tokenManager,
            logger: logger,
            sslPinningStrategy: sslPinningStrategy
        )
    }
    
    /// Creates a NetworkManager without SSL pinning
    /// - Parameters:
    ///   - tokenManager: The token manager instance
    ///   - logger: The network logger instance
    /// - Returns: A configured NetworkManager instance without SSL pinning
    public static func withoutSSLPinning(
        tokenManager: TokenManaging,
        logger: NetworkLogger
    ) -> NetworkManager {
        let noSSLPinningStrategy = SSLPinningDisabledStrategy()
        return NetworkManager(
            tokenManager: tokenManager,
            logger: logger,
            sslPinningStrategy: noSSLPinningStrategy
        )
    }
}
 
