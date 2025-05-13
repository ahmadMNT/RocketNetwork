//
//  TokenStorage.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for storing and retrieving authentication tokens
public protocol TokenStorage {
    /// Retrieve the stored access token, if any
    /// - Returns: The stored access token or nil if not available
    func getAccessToken() -> String?

    /// Retrieve the stored refresh token, if any
    /// - Returns: The stored refresh token or nil if not available
    func getRefreshToken() -> String?

    /// Store an access token
    /// - Parameter token: The access token to store, or nil to clear
    func storeAccessToken(_ token: String?)

    /// Store a refresh token
    /// - Parameter token: The refresh token to store, or nil to clear
    func storeRefreshToken(_ token: String?)
}
