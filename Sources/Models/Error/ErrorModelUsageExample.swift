//
//  ErrorModelUsageExample.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

// MARK: - Usage Examples for Error Model System

/// Example demonstrating how to use the new error model system
public struct ErrorModelUsageExamples {
    
    /// Example 1: Using DefaultErrorModel
    public static func defaultErrorModelExample() {
        // Create a structured error model
        let errorModel = DefaultErrorModel(
            message: "Authentication failed",
            code: "AUTH_001",
            details: ["Invalid credentials provided", "Account may be locked"],
            fieldErrors: [
                "email": ["Email format is invalid"],
                "password": ["Password must be at least 8 characters"]
            ]
        )
        
        // Use it with NetworkError
        let networkError = NetworkError.unauthenticatedWithModel(error: errorModel)
        
        print("Error message: \\(networkError.message)")
        print("Status code: \\(networkError.statusCode)")
        print("Error type: \\(networkError.errorType)")
        
        // Access structured error data
        if case .unauthenticatedWithModel(let errorModel) = networkError {
            print("Error code: \\(errorModel.code ?? \"No code\")")
            print("Has field errors: \\(errorModel.hasFieldErrors)")
            
            if let emailErrors = errorModel.errors(forField: "email") {
                print("Email errors: \\(emailErrors.joined(separator: \", \"))")
            }
        }
    }
    
    /// Example 2: Creating Custom Error Model
    public static func customErrorModelExample() {
        // Define a custom error model for a specific API
        struct APIErrorModel: ErrorModel {
            let message: String
            let code: String?
            let timestamp: String
            let requestId: String
            
            // Custom implementation for Equatable
            public static func == (lhs: APIErrorModel, rhs: APIErrorModel) -> Bool {
                return lhs.message == rhs.message &&
                       lhs.code == rhs.code &&
                       lhs.timestamp == rhs.timestamp &&
                       lhs.requestId == rhs.requestId
            }
        }
        
        // Register the custom error model
        ErrorModelConfiguration.registerCustomErrorModel(
            APIErrorModel.self,
            forErrorCode: "API_CUSTOM_ERROR"
        )
        
        // Use the custom error model
        let customError = APIErrorModel(
            message: "Custom API error",
            code: "API_CUSTOM_ERROR",
            timestamp: "2023-12-07T10:30:00Z",
            requestId: "req-123456"
        )
        
        let networkError = NetworkError.forbiddenWithModel(error: customError)
        print("Custom error: \\(networkError.message)")
    }
    
    /// Example 3: Error Model Factory Usage
    public static func errorModelFactoryExample() {
        let factory = DefaultErrorModelFactory()
        
        // Example JSON response from server
        let jsonResponse = """
        {
            "message": "Validation failed",
            "code": "VALIDATION_ERROR",
            "details": ["Required fields are missing"],
            "field_errors": {
                "username": ["Username is required"],
                "email": ["Email format is invalid"]
            }
        }
        """.data(using: .utf8)!
        
        // Extract error model from JSON
        if let errorModel = factory.createErrorModel(from: jsonResponse, type: DefaultErrorModel.self) {
            print("Extracted error: \\(errorModel.message)")
            print("Error code: \\(errorModel.code ?? \"No code\")")
            
            // Handle field-specific errors
            if errorModel.hasFieldErrors {
                print("Field validation errors:")
                if let fieldErrors = errorModel.fieldErrors {
                    for (field, errors) in fieldErrors {
                        print("  \\(field): \\(errors.joined(separator: \", \"))")
                    }
                }
            }
        }
    }
    
    /// Example 4: Configuration
    public static func configurationExample() {
        // Enable error model preference
        ErrorModelConfiguration.enableErrorModels()
        
        // Configure custom decoder
        ErrorModelConfiguration.configureDecoder { decoder in
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
        }
        
        // Set custom factory
        let customFactory = DefaultErrorModelFactory()
        ErrorModelConfiguration.setCustomFactory(customFactory)
        
        // Reset to defaults when needed
        // ErrorModelConfiguration.resetToDefaults()
    }
    
    /// Example 5: Response Processing with Error Models
    public static func responseProcessingExample() {
        // This shows how the ResponseProcessor now handles error models
        // In a real scenario, this would be handled automatically
        
        let errorData = """
        {
            "message": "Access denied",
            "code": "ACCESS_DENIED",
            "details": ["User does not have sufficient permissions"]
        }
        """.data(using: .utf8)!
        
        let decoder = StandardResponseDecoder()
        
        // Extract error model (this would be done internally by ResponseProcessor)
        if let errorModel = decoder.extractErrorModel(from: errorData) as? DefaultErrorModel {
            let networkError = NetworkError.forbiddenWithModel(error: errorModel)
            
            // Handle the structured error
            switch networkError {
            case .forbiddenWithModel(let errorModel):
                print("Forbidden error: \\(errorModel.message)")
                print("Error code: \\(errorModel.code ?? \"No code\")")
                
                // Take appropriate action based on error details
                if let details = errorModel.details {
                    print("Details: \\(details.joined(separator: \", \"))")
                }
            default:
                print("Other error: \\(networkError.message)")
            }
        }
    }
}
