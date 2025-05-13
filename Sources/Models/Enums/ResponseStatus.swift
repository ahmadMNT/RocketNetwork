//
//  ResponseStatus.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Common HTTP response status codes
public enum ResponseStatus {
    /// OK (200)
    public static let ok = 200

    /// Created (201)
    public static let created = 201

    /// Bad Request (400)
    public static let badRequest = 400

    /// Unauthorized (401)
    public static let unauthenticated = 401

    /// Forbidden (403)
    public static let noPermessions = 403

    /// Not Found (404)
    public static let notFound = 404

    /// Validation Error (422)
    public static let validation = 422

    /// Upgrade Required (426)
    public static let upgradeRequired = 426

    /// Token Expired (440 - Custom)
    public static let expired = 440

    /// Server Error (500)
    public static let serverError = 500
}
