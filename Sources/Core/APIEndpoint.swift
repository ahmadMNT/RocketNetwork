//
//  APIEndpoint.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol representing URL components for an API endpoint
public protocol URLComponents {
    /// The URL scheme (http or https)
    var scheme: String { get }
    
    /// The host domain name
    var host: String { get }
    
    /// The port number (optional)
    var port: Int? { get }
    
    /// The path component of the endpoint
    var path: String { get }
    
    /// The base URL composed of scheme, host, and port
    var baseURL: URL { get }
}

/// Protocol representing HTTP request properties
public protocol HTTPRequest {
    /// The HTTP method for the request
    var method: HTTPMethod { get }
    
    /// The request timeout in seconds
    var timeout: TimeInterval { get }
    
    /// The parameter encoding to use
    var encoding: ParameterEncoding { get }
    
    /// The content type header value
    var contentType: ContentType { get }
    
    /// The Accept header value specifying expected response format
    var accept: ContentType { get }
    
    /// The request headers
    var headers: [String: String] { get }
}

/// Protocol representing authentication for an API endpoint
public protocol APIAuthentication {
    /// The authentication credentials for this endpoint
    var authenticationCredentials: AuthenticationCredentials { get }
    
    /// Returns authorization header based on authentication credentials
    func getAuthorization() -> [String: String]?
}

/// Protocol representing parameters for an API endpoint
public protocol APIParameters {
    /// Query parameters to be appended to URL
    var queryParameters: [URLQueryItem] { get }
    
    /// Body parameters to be included in request body
    var bodyParameters: [String: Any]? { get }
    
    /// Raw body data to be sent directly (e.g., arrays without keys)
    var rawBodyData: Any? { get }
}

/// Protocol representing retry behavior for an API endpoint
public protocol RetryBehavior {
    /// Number of retry attempts in case of failure
    var retryCount: Int { get }
}

/// Protocol representing token refresh behavior for an API endpoint
public protocol TokenRefreshBehavior {
    /// Determines if this endpoint supports token refresh on authentication failure
    var supportsTokenRefresh: Bool { get }
}

/// Represents an API endpoint for making network requests
public protocol APIEndpoint: URLComponents, HTTPRequest, APIAuthentication, APIParameters, RetryBehavior, TokenRefreshBehavior {
    /// Builds the URLRequest for this endpoint
    func buildURLRequest() -> URLRequest
    
    /// Builds URLRequest with custom components (for dependency injection)
    func buildURLRequest(
        urlBuilder: URLBuilding,
        headerManager: HeaderManaging,
        parameterEncoder: ParameterEncodingStrategy,
        requestValidator: RequestValidating,
        requestInterceptor: RequestInterceptor
    ) throws -> URLRequest
}

/// Default implementation of APIEndpoint
extension APIEndpoint {
    public var scheme: String {
        return "https"  // Default to secure HTTPS
    }
    
    public var port: Int? {
        return nil  // Default to standard port for the scheme
    }
    
    public var timeout: TimeInterval {
        return 30.0  // Default 30 seconds timeout
    }
    
    public var encoding: ParameterEncoding {
        return .json  // Default to JSON encoding
    }
    
    public var contentType: ContentType {
        return .json  // Default to JSON content type
    }
    
    public var accept: ContentType {
        return .json  // Default to expecting JSON responses
    }
    
    public var retryCount: Int {
        return 1  // Default to 1 retry
    }
    
    public var supportsTokenRefresh: Bool {
        return true  // Default to supporting token refresh for authenticated endpoints
    }
    
    public var queryParameters: [URLQueryItem] {
        return []  // Default to empty query parameters
    }
    
    public var bodyParameters: [String: Any]? {
        return nil  // Default to no body parameters
    }
    
    public var rawBodyData: Any? {
        return nil  // Default to no raw body data
    }
    
    public var headers: [String: String] {
        return [:]  // Default to empty headers
    }
    
    public var authenticationCredentials: AuthenticationCredentials {
        return .none  // Default to no authentication
    }
    
    public func getAuthorization() -> [String: String]? {
        switch authenticationCredentials {
        case .none:
            return nil
        case let .bearer(token):
            return ["Authorization": "Bearer \(token)"]
        case let .basic(username, password):
            guard let credentialData = "\(username):\(password)".data(using: .utf8)
            else { return nil }
            let base64Credentials = credentialData.base64EncodedString()
            return ["Authorization": "Basic \(base64Credentials)"]
        case let .apiKey(key, value):
            return [key: value]
        case let .custom(token):
            return ["Authorization": "Basic \(token)"]
        }
    }
    
    public var baseURL: URL {
        var components = Foundation.URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        
        guard let url = components.url else {
            fatalError("Could not create base URL from components")
        }
        
        return url
    }
    
    public func buildURLRequest() -> URLRequest {
        // Create default components
        let urlBuilder = URLRequestBuilder()
        let headerManager = HeaderManager()
        let parameterEncoder = encoding.strategy
        let requestValidator = RequestValidator()
        let requestInterceptor = NoOpInterceptor()
        
        do {
            return try buildURLRequest(
                urlBuilder: urlBuilder,
                headerManager: headerManager,
                parameterEncoder: parameterEncoder,
                requestValidator: requestValidator,
                requestInterceptor: requestInterceptor
            )
        } catch {
            fatalError("Failed to build URLRequest: \(error)")
            // In production, you might want to return a result type instead
        }
    }
    
    /// Builds URLRequest with custom components (for dependency injection)
    public func buildURLRequest(
        urlBuilder: URLBuilding,
        headerManager: HeaderManaging,
        parameterEncoder: ParameterEncodingStrategy,
        requestValidator: RequestValidating,
        requestInterceptor: RequestInterceptor
    ) throws -> URLRequest {
        // Step 1: Build the URL
        let baseURL = try urlBuilder.buildURL(
            scheme: scheme,
            host: host,
            port: port,
            path: path
        )
        
        let finalURL = try urlBuilder.buildURLWithQuery(
            baseURL: baseURL,
            queryParameters: queryParameters
        )
        
        // Step 2: Create initial request
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout
        
        // Step 3: Apply pre-build interceptors
        try requestInterceptor.intercept(&request)
        
        // Step 4: Build headers
        let finalHeaders = headerManager.buildHeaders(
            baseHeaders: headers,
            authenticationCredentials: authenticationCredentials,
            contentType: contentType,
            accept: accept
        )
        
        // Step 5: Apply headers to request
        for (key, value) in finalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Step 6: Encode body parameters
        if let bodyParameters = bodyParameters, !bodyParameters.isEmpty,
           method != .get && method != .head {
            request.httpBody = try parameterEncoder.encodeBodyParameters(bodyParameters)
            
            // Override content type if encoder provides one
            if let contentTypeHeader = finalHeaders["Content-Type"],
               contentTypeHeader != parameterEncoder.contentType {
                request.setValue(parameterEncoder.contentType, forHTTPHeaderField: "Content-Type")
            }
        } else if let rawBodyData = rawBodyData, method != .get && method != .head {
            request.httpBody = try parameterEncoder.encodeRawBodyData(rawBodyData)
            
            // Override content type if encoder provides one
            if let contentTypeHeader = finalHeaders["Content-Type"],
               contentTypeHeader != parameterEncoder.contentType {
                request.setValue(parameterEncoder.contentType, forHTTPHeaderField: "Content-Type")
            }
        }
        
        // Step 7: Apply post-build interceptors
        try requestInterceptor.postBuild(&request)
        
        // Step 8: Validate the final request
        try requestValidator.validateRequest(
            method: method,
            url: finalURL,
            bodyParameters: bodyParameters,
            rawBodyData: rawBodyData,
            headers: finalHeaders
        )
        
        return request
    }
}
