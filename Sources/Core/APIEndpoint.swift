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
}

/// Protocol representing retry behavior for an API endpoint
public protocol RetryBehavior {
    /// Number of retry attempts in case of failure
    var retryCount: Int { get }
}

/// Represents an API endpoint for making network requests
public protocol APIEndpoint: URLComponents, HTTPRequest, APIAuthentication, APIParameters,
    RetryBehavior
{
    /// Builds the URLRequest for this endpoint
    func buildURLRequest() -> URLRequest
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

    public var queryParameters: [URLQueryItem] {
        return []  // Default to empty query parameters
    }

    public var bodyParameters: [String: Any]? {
        return nil  // Default to no body parameters
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
        // Start with base URL and append path
        let url = baseURL.appendingPathComponent(path)

        // Create URL components to handle query parameters
        var components = Foundation.URLComponents(url: url, resolvingAgainstBaseURL: true)!

        // Add query parameters if present
        if !queryParameters.isEmpty {
            components.queryItems = queryParameters
        }

        // Create request with the final URL
        guard let finalURL = components.url else {
            fatalError("Could not create URL from components")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout

        // Add headers
        var requestHeaders = headers

        // Add authorization headers
        if let authHeaders = getAuthorization() {
            for (key, value) in authHeaders {
                requestHeaders[key] = value
            }
        }

        // Set content type header if not already set
        if requestHeaders["Content-Type"] == nil {
            requestHeaders["Content-Type"] = contentType.rawValue
        }

        // Set accept header if not already set
        if requestHeaders["Accept"] == nil {
            requestHeaders["Accept"] = accept.rawValue
        }

        for (key, value) in requestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body parameters if present and method supports body
        if let bodyParameters = bodyParameters, !bodyParameters.isEmpty,
            method != .get && method != .head
        {
            do {
                // Set the body based on the encoding type
                switch encoding {
                case .json:
                    request.httpBody =
                        try JSONSerialization
                        .data(withJSONObject: bodyParameters)
                case .urlEncoded:
                    // Create a URL-encoded parameter string
                    request.httpBody = encodeURLParameters(parameters: bodyParameters)
                case let .formData(boundary):
                    // Create multipart form data with the specified boundary
                    request.httpBody = encodeFormData(
                        parameters: bodyParameters,
                        boundary: boundary
                    )
                    request.setValue(
                        "multipart/form-data; boundary=\(boundary)",
                        forHTTPHeaderField: "Content-Type"
                    )
                case let .custom(encoder):
                    request.httpBody = try encoder(bodyParameters)
                }
            } catch {
                print("Error encoding parameters: \(error)")
            }
        }

        return request
    }

    // Helper function to encode URL parameters
    private func encodeURLParameters(parameters: [String: Any]) -> Data? {
        let parameterString = parameters.map { key, value in
            let encodedKey =
                key
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let valueString = String(describing: value)
            let encodedValue =
                valueString
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? valueString
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        return parameterString.data(using: .utf8)
    }

    // Helper function to encode multipart form data
    private func encodeFormData(parameters: [String: Any], boundary: String) -> Data {
        var data = Data()

        // Add parameters
        for (key, value) in parameters {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)

            if let dataValue = value as? Data {
                // Handle file data
                data.append(
                    "Content-Disposition: form-data; name=\"\(key)\"; filename=\"file\"\r\n".data(
                        using: .utf8)!)
                data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                data.append(dataValue)
                data.append("\r\n".data(using: .utf8)!)
            } else {
                // Handle text data
                data.append(
                    "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                data.append("\(value)\r\n".data(using: .utf8)!)
            }
        }

        // Add final boundary
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return data
    }
}
