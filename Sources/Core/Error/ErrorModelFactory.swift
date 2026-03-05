//
//  ErrorModelFactory.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

// Import the error model types
// Note: These should be available in the same module

/// Factory protocol for creating appropriate error models from response data
/// Follows the Factory pattern to encapsulate error model creation logic
public protocol ErrorModelFactory {
    /// Creates a specific error model type from response data
    /// - Parameters:
    ///   - data: The response data containing error information
    ///   - type: The specific ErrorModel type to create
    /// - Returns: An instance of the specified ErrorModel type, or nil if creation fails
    func createErrorModel<E: ErrorModel>(from data: Data, type: E.Type) -> E?
    
    /// Extracts an error model from response data using the default error model type
    /// - Parameter data: The response data containing error information
    /// - Returns: An ErrorModel instance conforming to the protocol
    func extractErrorModel(from data: Data) -> any ErrorModel
    
    /// Attempts to extract an error model from data, trying multiple common formats
    /// - Parameter data: The response data containing error information
    /// - Returns: An ErrorModel instance if successful, nil otherwise
    func tryExtractErrorModel(from data: Data) -> (any ErrorModel)?
}

/// Default implementation of ErrorModelFactory
/// Provides flexible error model creation with support for various API response formats
public final class DefaultErrorModelFactory: ErrorModelFactory {
    public private(set) var decoder: JSONDecoder
    
    /// Initialize with a custom JSON decoder
    /// - Parameter decoder: JSON decoder to use for parsing error responses
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
        
        // Configure decoder for common API response formats
        decoder.keyDecodingStrategy = .useDefaultKeys
    }
    
    public func createErrorModel<E: ErrorModel>(from data: Data, type: E.Type) -> E? {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            // Log the error for debugging purposes
            #if DEBUG
            print("Failed to decode error model \(type.self): \(error)")
            #endif
            return nil
        }
    }
    
    public func extractErrorModel(from data: Data) -> any ErrorModel {
        // First try to extract DefaultErrorModel
        if let defaultError = createErrorModel(from: data, type: DefaultErrorModel.self) {
            return defaultError
        }
        
        // Fallback to simple ErrorResponse if available
        if let simpleError = try? decoder.decode(ErrorResponse.self, from: data) {
            return DefaultErrorModel(message: simpleError.message)
        }
        
        // Final fallback - create a generic error
        return DefaultErrorModel(
            message: "Unknown server error",
            code: "UNKNOWN_ERROR",
            statusCode: 500
        )
    }
    
    public func tryExtractErrorModel(from data: Data) -> (any ErrorModel)? {
        // Try to extract DefaultErrorModel first
        if let defaultError = createErrorModel(from: data, type: DefaultErrorModel.self) {
            return defaultError
        }
        
        // Try simple ErrorResponse
        if let simpleError = try? decoder.decode(ErrorResponse.self, from: data) {
            return DefaultErrorModel(message: simpleError.message)
        }
        
        // Try APIResponse with error information
        if let apiResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
            if let message = apiResponse.message {
                return DefaultErrorModel(
                    message: message,
                    code: "API_ERROR",
                    statusCode: apiResponse.statusCode
                )
            }
        }
        
        return nil
    }
}

// MARK: - Configuration Support

extension DefaultErrorModelFactory {
    /// Configures the decoder with custom key decoding strategy
    /// - Parameter strategy: The key decoding strategy to use
    public func configureKeyDecodingStrategy(_ strategy: JSONDecoder.KeyDecodingStrategy) {
        decoder.keyDecodingStrategy = strategy
    }
    
    /// Configures the decoder with custom date decoding strategy
    /// - Parameter strategy: The date decoding strategy to use
    public func configureDateDecodingStrategy(_ strategy: JSONDecoder.DateDecodingStrategy) {
        decoder.dateDecodingStrategy = strategy
    }
}

// MARK: - Error Model Registration

extension DefaultErrorModelFactory {
    /// Registry for custom error model types
    private static var customErrorModelTypes: [String: any ErrorModel.Type] = [:]
    
    /// Registry for custom error model types by status code
    private static var customErrorModelTypesByStatusCode: [Int: any ErrorModel.Type] = [:]
    
    /// Registers a custom error model type for a specific error code
    /// - Parameters:
    ///   - errorType: The custom ErrorModel type
    ///   - errorCode: The error code this type should handle
    public static func registerCustomErrorModel<T: ErrorModel>(_ errorType: T.Type, forErrorCode errorCode: String) {
        customErrorModelTypes[errorCode] = errorType
    }
    
    /// Registers a custom error model type for a specific status code
    /// - Parameters:
    ///   - errorType: The custom ErrorModel type
    ///   - statusCode: The HTTP status code this type should handle
    public static func registerCustomErrorModel<T: ErrorModel>(_ errorType: T.Type, forStatusCode statusCode: Int) {
        customErrorModelTypesByStatusCode[statusCode] = errorType
    }
    
    /// Gets the custom error model type for a specific error code
    /// - Parameter errorCode: The error code to look up
    /// - Returns: The custom ErrorModel type if registered, nil otherwise
    public static func getCustomErrorModel(forErrorCode errorCode: String) -> (any ErrorModel.Type)? {
        return customErrorModelTypes[errorCode]
    }
    
    /// Gets the custom error model type for a specific status code
    /// - Parameter statusCode: The HTTP status code to look up
    /// - Returns: The custom ErrorModel type if registered, nil otherwise
    public static func getCustomErrorModel(forStatusCode statusCode: Int) -> (any ErrorModel.Type)? {
        return customErrorModelTypesByStatusCode[statusCode]
    }
    
    /// Removes a custom error model registration
    /// - Parameter errorCode: The error code to remove
    public static func unregisterCustomErrorModel(forErrorCode errorCode: String) {
        customErrorModelTypes.removeValue(forKey: errorCode)
    }
    
    /// Removes a custom error model registration by status code
    /// - Parameter statusCode: The HTTP status code to remove
    public static func unregisterCustomErrorModel(forStatusCode statusCode: Int) {
        customErrorModelTypesByStatusCode.removeValue(forKey: statusCode)
    }
    
    /// Clears all custom error model registrations
    public static func clearCustomErrorModels() {
        customErrorModelTypes.removeAll()
        customErrorModelTypesByStatusCode.removeAll()
    }
}
