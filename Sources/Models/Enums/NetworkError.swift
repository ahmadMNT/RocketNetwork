//
//  NetworkError.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Represents errors that can occur during network operations
public enum NetworkError: Error, Equatable {
    /// The server returned an invalid or unexpected response
    case invalidResponse

    /// User is not authenticated
    case unauthenticated(error: any ErrorModel)

    /// User token has expired
    case tokenExpired(error: any ErrorModel)

    /// Error occurred during JSON decoding
    case decodingError(Error)

    /// Server returned an error status code
    case serverError(statusCode: Int)

    /// Server returned a specific error message
    case serverMessage(message: String)

    /// Validation error with message
    case validationError(error: any ErrorModel)

    /// Resource not found
    case notFound

    /// Maximum retry attempts were reached
    case maxRetriesExceeded

    /// Request was canceled
    case canceled

    /// User doesn't have permission
    case forbidden(error: any ErrorModel)

    /// App update is required
    case appUpdateRequired(error: any ErrorModel)

    /// No internet connection available
    case noInternetConnection

    /// Request timed out
    case requestTimedOut

    /// Bad request error (HTTP 400)
    case badRequest(error: any ErrorModel)

    /// Generic error case with underlying error
    case unknownError
    
    // MARK: - Error Message

    /// Human-readable error message
    public var message: String {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case let .unauthenticated(errorModel):
            return errorModel.message
        case let .tokenExpired(errorModel):
            return errorModel.message
        case let .decodingError(error):
            return "Could not process server response: \(error.localizedDescription)"
        case let .serverError(statusCode):
            return "Server error (\(statusCode))"
        case let .serverMessage(message):
            return message
        case let .validationError(errorModel):
            return errorModel.message
        case .notFound:
            return "Resource not found"
        case .maxRetriesExceeded:
            return "Request failed after multiple attempts"
        case .canceled:
            return "Request was canceled"
        case let .forbidden(errorModel):
            return errorModel.message
        case let .appUpdateRequired(errorModel):
            return errorModel.message
        case let .badRequest(errorModel):
            return errorModel.message
        case .noInternetConnection:
            return "No internet connection available"
        case .requestTimedOut:
            return "The request timed out"
        case .unknownError:
            return "An unknown error occurred"
        }
    }

    // MARK: - Error Type

    /// The type of error
    public var errorType: ErrorType {
        switch self {
        case .unauthenticated(_), .tokenExpired(_):
            return .unauthenticated
        case .forbidden(_):
            return .forbidden
        case .appUpdateRequired(_):
            return .upgradeRequired
        case .validationError(_), .badRequest(_):
            return .general
        case .noInternetConnection, .requestTimedOut:
            return .connectivity
        case .invalidResponse, .decodingError, .serverError, .maxRetriesExceeded, .canceled,
            .unknownError, .serverMessage, .notFound:
            return .general
        }
    }

    /// HTTP status code associated with this error
    public var statusCode: Int? {
        switch self {
        case .invalidResponse:
            return 500
        case .unauthenticated(_), .tokenExpired(_):
            return 401
        case .forbidden(_):
            return 403
        case .notFound:
            return 404
        case .validationError(_), .badRequest(_):
            return 400
        case .appUpdateRequired(_):
            return 426
        case .serverError(let code):
            return code
        case .noInternetConnection, .requestTimedOut, .canceled, .decodingError,
            .maxRetriesExceeded,
            .serverMessage, .unknownError:
            return nil
        }
    }

    /// Types of network errors
    public enum ErrorType {
        /// Authentication related errors
        case unauthenticated

        /// Permission related errors
        case forbidden

        /// App version related errors
        case upgradeRequired

        /// Network connectivity related errors
        case connectivity

        /// General errors
        case general
    }

    // MARK: - Equatable Implementation

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse):
            return true
        case let (.unauthenticated(lhsError), .unauthenticated(rhsError)):
            return lhsError.message == rhsError.message
        case let (.tokenExpired(lhsError), .tokenExpired(rhsError)):
            return lhsError.message == rhsError.message
        case (.maxRetriesExceeded, .maxRetriesExceeded):
            return true
        case (.canceled, .canceled):
            return true
        case (.notFound, .notFound):
            return true
        case let (.forbidden(lhsError), .forbidden(rhsError)):
            return lhsError.message == rhsError.message
        case let (.appUpdateRequired(lhsError), .appUpdateRequired(rhsError)):
            return lhsError.message == rhsError.message
        case let (.validationError(lhsError), .validationError(rhsError)):
            return lhsError.message == rhsError.message
        case let (.badRequest(lhsError), .badRequest(rhsError)):
            return lhsError.message == rhsError.message
        case (.unknownError, .unknownError):
            return true
        case (.noInternetConnection, .noInternetConnection):
            return true
        case (.requestTimedOut, .requestTimedOut):
            return true
        case let (.serverError(lhsCode), .serverError(rhsCode)):
            return lhsCode == rhsCode
        case let (.serverMessage(lhsMsg), .serverMessage(rhsMsg)):
            return lhsMsg == rhsMsg
        case (.decodingError, .decodingError):
            // These can't be directly compared because they contain errors
            return false
        default:
            return false
        }
    }

    // MARK: - Backward Compatibility

    /// A simple unauthorized error - for compatibility with code using 'unauthorized'
    public static var unauthorized: NetworkError {
        return .unauthenticated(error: DefaultErrorModel(message: "Authentication required"))
    }

    /// A simple server error - for compatibility with code using 'serverError'
    public static var serverError: NetworkError {
        return .serverError(statusCode: 500)
    }

    /// A simple unknown error - for compatibility with code using 'unknown'
    public static var unknown: NetworkError {
        return .unknownError
    }

    /// Create a NetworkError from a general Error
    /// - Parameter error: The source error
    /// - Returns: A NetworkError representation of the error
    public static func from(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }

        // Handle URL errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternetConnection
            case .timedOut:
                return .requestTimedOut
            case .cancelled:
                return .canceled
            default:
                return .serverMessage(message: urlError.localizedDescription)
            }
        }

        // Default case
        return .serverMessage(message: error.localizedDescription)
    }
}
