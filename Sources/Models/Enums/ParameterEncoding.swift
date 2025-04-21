//
//  ParameterEncoding.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Parameter encoding types for API requests
public enum ParameterEncoding {
    /// JSON encoding
    case json
    
    /// URL encoded parameters
    case urlEncoded
    
    /// Multipart form data with boundary
    case formData(boundary: String)
    
    /// Custom encoding with a closure
    case custom(encoder: ([String: Any]) throws -> Data)
} 
