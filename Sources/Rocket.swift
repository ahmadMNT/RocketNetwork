//
//  Rocket.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

// Re-export key types for easier access

// Core
public typealias Network = NetworkManager
public typealias NetworkResponse<T: Decodable> = APIResponse<T>

// Protocols
public typealias Endpoint = APIEndpoint
public typealias TokenManager = TokenManaging

// Factories
public let SSLPinning = SSLPinningEnabledStrategy.self
public let NoSSLPinning = SSLPinningDisabledStrategy.self 