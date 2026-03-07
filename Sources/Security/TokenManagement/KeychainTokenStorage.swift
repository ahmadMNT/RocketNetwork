//
//  KeychainTokenStorage.swift
//  Rocket
//
//  Created as part of token management refactoring.
//

import Foundation

/// Protocol for token storage operations to allow flexible implementations
public protocol TokenStorageProvider {
    /// Get token for a specific key
    /// - Parameter key: The key to retrieve token for
    /// - Returns: The stored token or nil if not found
    func getToken(for key: TokenKey) -> String?
    
    /// Save token for a specific key
    /// - Parameters:
    ///   - token: The token to save (nil to clear)
    ///   - key: The key to save token under
    func saveToken(_ token: String?, for key: TokenKey)
    
    /// Clear all tokens
    func clearAllTokens()
}

/// Keys for different token types
public enum TokenKey {
    case accessToken
    case refreshToken
    
    /// String representation of the key
    var stringValue: String {
        switch self {
        case .accessToken:
            return "access_token"
        case .refreshToken:
            return "refresh_token"
        }
    }
}

/// Token storage implementation using a configurable provider
public final class KeychainTokenStorage: TokenStorage {
    private let provider: TokenStorageProvider
    
    /// Initialize with a custom token storage provider
    /// - Parameter provider: The provider to use for token operations
    public init(provider: TokenStorageProvider) {
        self.provider = provider
    }
    
    /// Convenience initializer for common keychain-based storage
    public init() {
        // Default implementation using a simple keychain provider
        self.provider = DefaultKeychainProvider()
    }
    
    /// Retrieve the stored access token
    /// - Returns: The stored access token or nil if not available
    public func getAccessToken() -> String? {
        return provider.getToken(for: .accessToken)
    }
    
    /// Retrieve the stored refresh token
    /// - Returns: The stored refresh token or nil if not available
    public func getRefreshToken() -> String? {
        return provider.getToken(for: .refreshToken)
    }
    
    /// Store an access token
    /// - Parameter token: The access token to store, or nil to clear
    public func storeAccessToken(_ token: String?) {
        provider.saveToken(token, for: .accessToken)
    }
    
    /// Store a refresh token
    /// - Parameter token: The refresh token to store, or nil to clear
    public func storeRefreshToken(_ token: String?) {
        provider.saveToken(token, for: .refreshToken)
    }
}

/// Default keychain provider implementation
public final class DefaultKeychainProvider: TokenStorageProvider {
    public init() {}
    
    public func getToken(for key: TokenKey) -> String? {
        // Default implementation using iOS Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.stringValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    public func saveToken(_ token: String?, for key: TokenKey) {
        let account = key.stringValue
        
        // First, delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // If token is nil, we're done (clear operation)
        guard let token = token else { return }
        
        // Save the new token
        let data = token.data(using: .utf8)!
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save failed with status: \(status)")
        }
    }
    
    public func clearAllTokens() {
        // Clear access token
        saveToken(nil, for: .accessToken)
        // Clear refresh token
        saveToken(nil, for: .refreshToken)
    }
}
