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
    case unauthenticated

    /// User token has expired
    case tokenExpired

    /// Error occurred during JSON decoding
    case decodingError(Error)

    /// Server returned an error status code
    case serverError(statusCode: Int)

    /// Server returned a specific error message
    case serverMessage(message: String)

    /// Validation error with message
    case validationError(message: String)

    /// Resource not found
    case notFound

    /// Maximum retry attempts were reached
    case maxRetriesExceeded

    /// Request was canceled
    case canceled

    /// User doesn't have permission
    case forbidden

    /// App update is required
    case appUpdateRequired

    /// No internet connection available
    case noInternetConnection

    /// Request timed out
    case requestTimedOut

    /// Bad request error (HTTP 400)
    case badRequest

    /// Generic error case with underlying error
    case unknownError

    // MARK: - Error Message

    /// Human-readable error message
    public var message: String {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .unauthenticated:
            return "Authentication required"
        case .tokenExpired:
            return "Session expired, please login again"
        case let .decodingError(error):
            return "Could not process server response: \(error.localizedDescription)"
        case let .serverError(statusCode):
            return "Server error (\(statusCode))"
        case let .serverMessage(message):
            return message
        case let .validationError(message):
            return message
        case .notFound:
            return "Resource not found"
        case .maxRetriesExceeded:
            return "Request failed after multiple attempts"
        case .canceled:
            return "Request was canceled"
        case .forbidden:
            return "You don't have permission to access this resource"
        case .appUpdateRequired:
            return "Please update your app to continue"
        case .noInternetConnection:
            return "No internet connection available"
        case .requestTimedOut:
            return "The request timed out"
        case .badRequest:
            return "Bad request"
        case .unknownError:
            return "An unknown error occurred"
        }
    }

    // MARK: - Error Type

    /// The type of error
    public var errorType: ErrorType {
        switch self {
        case .unauthenticated, .tokenExpired:
            return .unauthenticated
        case .forbidden:
            return .forbidden
        case .appUpdateRequired:
            return .upgradeRequired
        case .noInternetConnection, .requestTimedOut:
            return .connectivity
        case .invalidResponse, .decodingError, .serverError, .maxRetriesExceeded, .canceled,
            .unknownError, .serverMessage, .validationError, .notFound, .badRequest:
            return .general
        }
    }

    /// HTTP status code associated with this error
    public var statusCode: Int? {
        switch self {
        case .invalidResponse:
            return 500
        case .unauthenticated, .tokenExpired:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .badRequest, .validationError:
            return 400
        case .appUpdateRequired:
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
        case (.unauthenticated, .unauthenticated):
            return true
        case (.tokenExpired, .tokenExpired):
            return true
        case (.maxRetriesExceeded, .maxRetriesExceeded):
            return true
        case (.canceled, .canceled):
            return true
        case (.notFound, .notFound):
            return true
        case (.forbidden, .forbidden):
            return true
        case (.appUpdateRequired, .appUpdateRequired):
            return true
        case (.unknownError, .unknownError):
            return true
        case (.noInternetConnection, .noInternetConnection):
            return true
        case (.requestTimedOut, .requestTimedOut):
            return true
        case (.badRequest, .badRequest):
            return true
        case let (.serverError(lhsCode), .serverError(rhsCode)):
            return lhsCode == rhsCode
        case let (.serverMessage(lhsMsg), .serverMessage(rhsMsg)):
            return lhsMsg == rhsMsg
        case let (.validationError(lhsMsg), .validationError(rhsMsg)):
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
        return .unauthenticated
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
