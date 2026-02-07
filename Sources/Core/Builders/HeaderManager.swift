//
//  HeaderManager.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for managing HTTP headers and authentication
public protocol HeaderManaging {
    /// Builds complete headers including authentication and content type
    func buildHeaders(
        baseHeaders: [String: String],
        authenticationCredentials: AuthenticationCredentials,
        contentType: ContentType,
        accept: ContentType
    ) -> [String: String]
}

/// Default implementation of header management
public struct HeaderManager: HeaderManaging {
    
    public init() {}
    
    /// Builds complete headers including authentication and content type
    public func buildHeaders(
        baseHeaders: [String: String],
        authenticationCredentials: AuthenticationCredentials,
        contentType: ContentType,
        accept: ContentType
    ) -> [String: String] {
        var requestHeaders = baseHeaders
        
        // Add authentication headers
        if let authHeaders = buildAuthenticationHeaders(from: authenticationCredentials) {
            for (key, value) in authHeaders {
                requestHeaders[key] = value
            }
        }
        
        // Set content type header if not already set
        if requestHeaders["Content-Type"] == nil {
            requestHeaders["Content-Type"] = contentType.rawValue
        }
        
        // Set accept header if not already set
        if requestHeaders["Accept"] == nil {
            requestHeaders["Accept"] = accept.rawValue
        }
        
        return requestHeaders
    }
    
    /// Builds authentication headers based on credentials
    private func buildAuthenticationHeaders(from credentials: AuthenticationCredentials) -> [String: String]? {
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
