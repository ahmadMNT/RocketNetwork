//
//  ErrorModel.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Base protocol for all error models
/// Provides a contract for structured error handling throughout the network layer
public protocol ErrorModel: Error, Decodable, Equatable {
    /// Human-readable error message
    var message: String { get }
    
    /// Optional error code for programmatic handling
    var code: String? { get }
    
    /// Optional status code for programmatic handling
    var statusCode: Int? { get }
}

/// Default structured error model implementation
/// Provides comprehensive error information with optional details and field validation errors
public struct DefaultErrorModel: ErrorModel {
    /// Human-readable error message
    public let message: String
    
    /// Optional error code for programmatic handling
    public let code: String?

    /// Optional status code for programmatic handling
    public let statusCode: Int?
    
    
    /// Public initializer for creating error instances
    /// - Parameters:
    ///   - message: Human-readable error message
    ///   - code: Optional error code for programmatic handling
    ///   - statusCode: Optional status code for programmatic handling
    public init(
        message: String,
        code: String? = nil,
        statusCode: Int? = nil
    ) {
        self.message = message
        self.code = code
        self.statusCode = statusCode
    }
}

// MARK: - Decodable Implementation

extension DefaultErrorModel {
    /// Custom coding keys for flexible decoding from various API response formats
    public enum CodingKeys: String, CodingKey {
        case message = "message"
        case code = "code"
        case statusCode = "status_code"
    }
    
    /// Custom initializer to handle various API response formats
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode message from various possible keys
        if let message = try? container.decode(String.self, forKey: .message) {
            self.message = message
        } else {
            self.message = "Unknown error occurred"
        }
        
        // Decode optional fields
        self.code = try? container.decodeIfPresent(String.self, forKey: .code)
        self.statusCode = try? container.decodeIfPresent(Int.self, forKey: .statusCode)
    }
}

// MARK: - Equatable Implementation

extension DefaultErrorModel {
    /// Equality comparison based on all properties
    public static func == (lhs: DefaultErrorModel, rhs: DefaultErrorModel) -> Bool {
        return lhs.message == rhs.message &&
               lhs.code == rhs.code &&
               lhs.statusCode == rhs.statusCode
    }
}

// MARK: - Utility Extensions

extension DefaultErrorModel {
    /// Returns a user-friendly description of the error
    public var description: String {
        var result = message
        
        if let code = code {
            result += " (Code: \(code))"
        }
        
        if let statusCode = statusCode {
            result += " (Status Code: \(statusCode))"
        }
        
        return result
    }
}
