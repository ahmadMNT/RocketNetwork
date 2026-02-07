//
//  EncodingStrategyFactory.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Factory for creating parameter encoding strategies from ParameterEncoding enum
public struct EncodingStrategyFactory {
    
    /// Creates a parameter encoding strategy from the ParameterEncoding enum
    public static func createStrategy(from encoding: ParameterEncoding) -> ParameterEncodingStrategy {
        switch encoding {
        case .json:
            return JSONParameterEncoder()
        case .urlEncoded:
            return URLParameterEncoder()
        case let .formData(boundary):
            return FormDataParameterEncoder(boundary: boundary)
        case let .custom(encoder):
            return CustomParameterEncoder(encoder: encoder, contentType: "application/json")
        }
    }
}

/// Extension to make ParameterEncoding enum work with new strategies
public extension ParameterEncoding {
    /// Converts to ParameterEncodingStrategy
    var strategy: ParameterEncodingStrategy {
        return EncodingStrategyFactory.createStrategy(from: self)
    }
}
