//
//  AuthenticationStrategy.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for handling authentication strategies
public protocol AuthenticationStrategy {
    /// Returns authorization headers based on credentials
    func getAuthorizationHeaders(from credentials: AuthenticationCredentials) -> [String: String]?
}

/// Default implementation of authentication strategy
public struct DefaultAuthenticationStrategy: AuthenticationStrategy {
    
    public init() {}
    
    /// Returns authorization headers based on credentials
    public func getAuthorizationHeaders(from credentials: AuthenticationCredentials) -> [String: String]? {
        switch credentials {
        case .none:
            return nil
        case let .bearer(token):
            return ["Authorization": "Bearer \(token)"]
        case let .basic(username, password):
            guard let credentialData = "\(username):\(password)".data(using: .utf8) else {
                return nil
            }
            let base64Credentials = credentialData.base64EncodedString()
            return ["Authorization": "Basic \(base64Credentials)"]
        case let .apiKey(key, value):
            return [key: value]
        case let .custom(token):
            return ["Authorization": "Basic \(token)"]
        }
    }
}

/// Factory for creating authentication strategies
public struct AuthenticationStrategyFactory {
    
    /// Creates the default authentication strategy
    public static func createDefault() -> AuthenticationStrategy {
        return DefaultAuthenticationStrategy()
    }
    
    /// Creates a custom authentication strategy
    public static func createCustom(strategy: AuthenticationStrategy) -> AuthenticationStrategy {
        return strategy
    }
}
