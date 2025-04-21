//
//  ResponseProcessor.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for processing HTTP responses
public protocol ResponseProcessorProtocol {
    /// Process HTTP response data and convert to model objects
    /// - Parameters:
    ///   - data: The response data
    ///   - response: The HTTP response
    /// - Returns: Result with decoded data or error
    func process<T: Decodable>(data: Data, response: URLResponse) throws -> Result<T, NetworkError>
}

/// Protocol for handling HTTP status codes
public protocol StatusCodeHandler {
    /// Validate HTTP status code and throw appropriate error if needed
    /// - Parameter statusCode: The HTTP status code to validate
    /// - Throws: NetworkError if the status code indicates an error
    func validate(statusCode: Int) throws
}

/// Protocol for decoding response data
public protocol ResponseDecoder {
    /// Decode response data into target type
    /// - Parameters:
    ///   - data: The data to decode
    ///   - statusCode: The HTTP status code (for context)
    /// - Returns: Decoded object of specified type
    /// - Throws: NetworkError if decoding fails
    func decode<T: Decodable>(data: Data, statusCode: Int) throws -> T

    /// Attempt to extract error message from data
    /// - Parameter data: The response data that contains error information
    /// - Returns: NetworkError with extracted message
    func extractErrorFromData(_ data: Data) -> NetworkError
}

/// Simple error response structure used by some APIs
public struct ErrorResponse: Decodable {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}

/// Default implementation of ResponseDecoder protocol
public final class StandardResponseDecoder: ResponseDecoder {
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder

        // Configure decoder for API response format
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .iso8601
    }

    public func decode<T: Decodable>(data: Data, statusCode: Int) throws -> T {
        do {
            // First try to decode as APIResponse wrapper
            if let apiResponse = try? decoder.decode(APIResponse<T>.self, from: data) {
                // If success is false, return the error message
                if !apiResponse.success {
                    throw NetworkError.serverMessage(message: apiResponse.message ?? "Unknown error")
                }

                // If data exists, return it
                if let responseData = apiResponse.data {
                    return responseData
                }
            }

            // Fallback: try to decode directly as T
            return try decoder.decode(T.self, from: data)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    public func extractErrorFromData(_ data: Data) -> NetworkError {
        // Try to decode error in {"message":"Error Message"} format first
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            return .serverMessage(message: errorResponse.message)
        }

        // Then try to decode standard APIResponse error format
        if let errorResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
            return .serverMessage(message: errorResponse.message ?? "Unknown error")
        }

        return .invalidResponse
    }
}

/// Default implementation of StatusCodeHandler
public final class StandardStatusCodeHandler: StatusCodeHandler {
    public init() {}
    
    public func validate(statusCode: Int) throws {
        switch statusCode {
            case ResponseStatus.ok, ResponseStatus.created:
                return // Success, no error to throw
            case ResponseStatus.unauthenticated:
                throw NetworkError.unauthenticated
            case ResponseStatus.expired:
                throw NetworkError.tokenExpired
            case ResponseStatus.badRequest:
                throw NetworkError.badRequest
            case ResponseStatus.validation:
                throw NetworkError.validationError(message: "Validation error")
            case ResponseStatus.notFound:
                throw NetworkError.notFound
            case ResponseStatus.upgradeRequired:
                throw NetworkError.appUpdateRequired
            case ResponseStatus.noPermessions:
                throw NetworkError.forbidden
            case ResponseStatus.serverError:
                throw NetworkError.serverError(statusCode: statusCode)
            default:
                if statusCode >= 500 {
                    throw NetworkError.serverError(statusCode: statusCode)
                } else if statusCode >= 400 {
                    throw NetworkError.serverMessage(message: "Request failed with status code \(statusCode)")
                }
        }
    }
}

/// Default implementation of ResponseProcessorProtocol
public final class DefaultResponseProcessor: ResponseProcessorProtocol {
    private let decoder: ResponseDecoder
    private let statusCodeHandler: StatusCodeHandler

    public init(
        decoder: ResponseDecoder = StandardResponseDecoder(),
        statusCodeHandler: StatusCodeHandler = StandardStatusCodeHandler()
    ) {
        self.decoder = decoder
        self.statusCodeHandler = statusCodeHandler
    }

    public func process<T: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> Result<T, NetworkError> {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        do {
            // Validate status code first
            try statusCodeHandler.validate(statusCode: statusCode)

            // If we reach here, status is OK, decode the data
            let decoded: T = try decoder.decode(data: data, statusCode: statusCode)
            return .success(decoded)
        } catch let error as NetworkError {
            // Use extractErrorFromData for all non-authentication related errors
            // This way we always try to extract meaningful error messages from the response
            switch error {
                case .unauthenticated, .tokenExpired, .forbidden, .appUpdateRequired:
                    // For these specific errors, just pass through the error as is
                    return .failure(error)
                case .decodingError:
                    // Preserve the original decoding error
                    return .failure(error)
                default:
                    // For all other errors, try to extract a more detailed message from the
                    // response data
                    return .failure(decoder.extractErrorFromData(data))
            }
        } catch {
            // Handle any other errors
            return .failure(NetworkError.decodingError(error))
        }
    }
} 
