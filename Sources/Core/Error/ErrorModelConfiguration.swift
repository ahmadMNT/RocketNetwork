//
//  ErrorModelConfiguration.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

// Import error model types - these should be available in the same module

/// Configuration for error model handling
/// Provides centralized configuration for error model types and behavior
public struct ErrorModelConfiguration {
    /// The default error model type to use when extracting errors
    public static var defaultErrorModelType: any ErrorModel.Type = DefaultErrorModel.self
    
    /// Whether to prefer error models over string messages when both are available
    public static var preferErrorModels: Bool = true
    
    /// Custom error model factory to use (optional)
    public static var customFactory: ErrorModelFactory?
    
    /// Register a custom error model type for a specific error code
    /// - Parameters:
    ///   - errorType: The custom ErrorModel type
    ///   - errorCode: The error code this type should handle
    public static func registerCustomErrorModel<T: ErrorModel>(_ errorType: T.Type, forErrorCode errorCode: String) {
        DefaultErrorModelFactory.registerCustomErrorModel(errorType, forErrorCode: errorCode)
    }
    
    /// Register a custom error model type for a specific status code
    /// - Parameters:
    ///   - errorType: The custom ErrorModel type
    ///   - statusCode: The HTTP status code this type should handle
    public static func registerCustomErrorModel<T: ErrorModel>(_ errorType: T.Type, forStatusCode statusCode: Int) {
        DefaultErrorModelFactory.registerCustomErrorModel(errorType, forStatusCode: statusCode)
    }
    
    /// Set the general error model type to use as fallback for all status codes
    /// - Parameter errorType: The custom ErrorModel type to use as default
    public static func setGeneralErrorModel<T: ErrorModel>(_ errorType: T.Type) {
        defaultErrorModelType = errorType
    }
    
    /// Gets the appropriate error model factory
    /// - Returns: Configured error model factory
    public static func getErrorModelFactory() -> ErrorModelFactory {
        return customFactory ?? DefaultErrorModelFactory()
    }
    
    /// Configure the default JSON decoder for error model parsing
    /// - Parameter configuration: Configuration block for the decoder
    public static func configureDecoder(_ configuration: (JSONDecoder) -> Void) {
        let factory = DefaultErrorModelFactory()
        configuration(factory.decoder)
        customFactory = factory
    }
    
    /// Reset configuration to defaults
    public static func resetToDefaults() {
        defaultErrorModelType = DefaultErrorModel.self
        preferErrorModels = true
        customFactory = nil
        DefaultErrorModelFactory.clearCustomErrorModels()
    }
}

// MARK: - Convenience Extensions

extension ErrorModelConfiguration {
    /// Enable error model preference for structured error handling
    public static func enableErrorModels() {
        preferErrorModels = true
    }
    
    /// Disable error model preference (fallback to string messages)
    public static func disableErrorModels() {
        preferErrorModels = false
    }
    
    /// Set custom error model factory
    /// - Parameter factory: Custom factory implementation
    public static func setCustomFactory(_ factory: ErrorModelFactory) {
        customFactory = factory
    }
}
