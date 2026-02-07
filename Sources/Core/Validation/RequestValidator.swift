//
//  RequestValidator.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for validating API requests before building
public protocol RequestValidating {
    /// Validates the request components and throws errors if invalid
    func validateRequest(
        method: HTTPMethod,
        url: URL,
        bodyParameters: [String: Any]?,
        rawBodyData: Any?,
        headers: [String: String]
    ) throws
}

/// Default implementation of request validation
public struct RequestValidator: RequestValidating {
    
    public init() {}
    
    /// Validates the request components and throws errors if invalid
    public func validateRequest(
        method: HTTPMethod,
        url: URL,
        bodyParameters: [String: Any]?,
        rawBodyData: Any?,
        headers: [String: String]
    ) throws {
        // Validate URL
        try validateURL(url)
        
        // Validate method and body compatibility
        try validateMethodBodyCompatibility(method: method, bodyParameters: bodyParameters, rawBodyData: rawBodyData)
        
        // Validate headers
        try validateHeaders(headers)
    }
    
    // MARK: - Private Validation Methods
    
    private func validateURL(_ url: URL) throws {
        guard url.scheme != nil else {
            throw ValidationError.missingURLScheme
        }
        
        guard url.host != nil else {
            throw ValidationError.missingURLHost
        }
        
        guard let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https") else {
            throw ValidationError.invalidURLScheme
        }
    }
    
    private func validateMethodBodyCompatibility(
        method: HTTPMethod,
        bodyParameters: [String: Any]?,
        rawBodyData: Any?
    ) throws {
        let hasBody = (bodyParameters != nil && !bodyParameters!.isEmpty) || rawBodyData != nil
        let bodyNotAllowed = method == .get || method == .head
        
        if hasBody && bodyNotAllowed {
            throw ValidationError.bodyNotAllowedForMethod(method)
        }
    }
    
    private func validateHeaders(_ headers: [String: String]) throws {
        // Check for required headers based on content type
        if let contentType = headers["Content-Type"] {
            try validateContentTypeHeader(contentType)
        }
        
        if let accept = headers["Accept"] {
            try validateAcceptHeader(accept)
        }
    }
    
    private func validateContentTypeHeader(_ contentType: String) throws {
        let validContentTypes = [
            "application/json",
            "application/x-www-form-urlencoded",
            "multipart/form-data",
            "text/plain",
            "application/xml"
        ]
        
        // For multipart/form-data, just check the prefix
        if contentType.hasPrefix("multipart/form-data") {
            return
        }
        
        guard validContentTypes.contains(contentType) else {
            throw ValidationError.invalidContentType(contentType)
        }
    }
    
    private func validateAcceptHeader(_ accept: String) throws {
        let validAcceptTypes = [
            "application/json",
            "application/x-www-form-urlencoded",
            "multipart/form-data",
            "text/plain",
            "application/xml",
            "*/*"
        ]
        
        guard validAcceptTypes.contains(accept) else {
            throw ValidationError.invalidAcceptType(accept)
        }
    }
}

/// Request validation errors
public enum ValidationError: Error, LocalizedError {
    case missingURLScheme
    case missingURLHost
    case invalidURLScheme
    case bodyNotAllowedForMethod(HTTPMethod)
    case invalidContentType(String)
    case invalidAcceptType(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingURLScheme:
            return "URL scheme is missing"
        case .missingURLHost:
            return "URL host is missing"
        case .invalidURLScheme:
            return "URL scheme must be http or https"
        case .bodyNotAllowedForMethod(let method):
            return "Request body is not allowed for \(method.rawValue) method"
        case .invalidContentType(let contentType):
            return "Invalid content type: \(contentType)"
        case .invalidAcceptType(let accept):
            return "Invalid accept type: \(accept)"
        }
    }
}
