//
//  HTTPMethod.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// HTTP methods for network requests
public enum HTTPMethod: String {
    /// GET method for retrieving resources
    case get = "GET"

    /// POST method for creating resources
    case post = "POST"

    /// PUT method for updating resources
    case put = "PUT"

    /// DELETE method for removing resources
    case delete = "DELETE"

    /// PATCH method for partially updating resources
    case patch = "PATCH"

    /// HEAD method for retrieving headers only
    case head = "HEAD"
}
