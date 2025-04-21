//
//  ContentType.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Content types for HTTP requests and responses
public enum ContentType: String {
    /// JSON content type
    case json = "application/json"
    
    /// URL-encoded form data
    case urlEncoded = "application/x-www-form-urlencoded"
    
    /// Multipart form data
    case multipartFormData = "multipart/form-data"
    
    /// Plain text content
    case text = "text/plain"
    
    /// XML content
    case xml = "application/xml"
} 
