//
//  APIResponse.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// A generic structure representing a standard API response
///
/// This structure wraps the response data from API calls with additional
/// metadata such as success status, message, and status code.
public struct APIResponse<T: Decodable>: Decodable {
    /// Whether the request was successful
    public let success: Bool

    /// Optional message from the server, often used for error messages
    public let message: String?

    /// The actual data payload of the response
    public let data: T?

    /// HTTP status code returned by the server
    public let statusCode: Int?

    /// Public initializer
    public init(success: Bool, message: String? = nil, data: T? = nil, statusCode: Int? = nil) {
        self.success = success
        self.message = message
        self.data = data
        self.statusCode = statusCode
    }

    /// Custom coding keys for decoding API responses
    /// Override these in an extension if your API uses different key names
    public enum CodingKeys: String, CodingKey {
        case success = "Success"
        case message = "Message"
        case data = "Data"
        case statusCode = "StatusCode"
    }
}

// MARK: - Utility Methods

extension APIResponse {
    /// Returns a user-friendly error message from the response
    public var errorMessage: String {
        return message ?? "Unknown error occurred"
    }

    /// Returns true if the response contains valid data
    public var hasData: Bool {
        return data != nil
    }

    /// Maps an APIResponse to another type using a transform function
    /// - Parameter transform: A function to transform the data to another type
    /// - Returns: A new APIResponse with transformed data
    public func map<U: Decodable>(_ transform: (T) -> U) -> APIResponse<U> where T: Decodable {
        return APIResponse<U>(
            success: success,
            message: message,
            data: data.map(transform),
            statusCode: statusCode
        )
    }

    /// Creates a failure response with an error message
    /// - Parameter message: The error message
    /// - Returns: A new APIResponse indicating failure
    public static func failure(message: String) -> APIResponse<T> {
        return APIResponse<T>(
            success: false,
            message: message,
            data: nil,
            statusCode: nil
        )
    }

    /// Creates a success response with data
    /// - Parameter data: The data to include in the response
    /// - Returns: A new APIResponse indicating success
    public static func success(data: T) -> APIResponse<T> {
        return APIResponse<T>(
            success: true,
            message: nil,
            data: data,
            statusCode: 200
        )
    }
}
