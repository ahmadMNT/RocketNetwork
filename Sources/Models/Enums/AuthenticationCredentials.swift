//
//  AuthenticationCredentials.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Authentication credentials for API requests
public enum AuthenticationCredentials {
    /// No authentication
    case none
    
    /// Bearer token authentication
    case bearer(token: String)
    
    /// Basic authentication with username and password
    case basic(username: String, password: String)
    
    /// API key authentication with key and value
    case apiKey(key: String, value: String)
    
    /// Custom token authentication
    case custom(token: String)
} 
