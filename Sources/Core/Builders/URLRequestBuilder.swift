//
//  URLRequestBuilder.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for building URLs from components
public protocol URLBuilding {
    /// Builds the complete URL from base components and path
    func buildURL(scheme: String, host: String, port: Int?, path: String) throws -> URL
    
    /// Builds URL with query parameters
    func buildURLWithQuery(baseURL: URL, queryParameters: [URLQueryItem]) throws -> URL
}

/// Default implementation of URL building
public struct URLRequestBuilder: URLBuilding {
    
    public init() {}
    
    /// Builds the complete URL from base components and path
    public func buildURL(scheme: String, host: String, port: Int?, path: String) throws -> URL {
        var components = Foundation.URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        
        guard let baseURL = components.url else {
            throw URLError(.badURL)
        }
        
        return baseURL.appendingPathComponent(path)
    }
    
    /// Builds URL with query parameters
    public func buildURLWithQuery(baseURL: URL, queryParameters: [URLQueryItem]) throws -> URL {
        guard !queryParameters.isEmpty else {
            return baseURL
        }
        
        var components = Foundation.URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        components.queryItems = queryParameters
        
        guard let finalURL = components.url else {
            throw URLError(.badURL)
        }
        
        return finalURL
    }
}
