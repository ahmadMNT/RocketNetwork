//
//  ParameterEncoder.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for encoding parameters into HTTP request body
public protocol ParameterEncodingStrategy {
    /// Encodes body parameters into Data
    func encodeBodyParameters(_ parameters: [String: Any]) throws -> Data
    
    /// Encodes raw body data (e.g., arrays without keys) into Data
    func encodeRawBodyData(_ data: Any) throws -> Data
    
    /// Returns the content type for this encoding
    var contentType: String { get }
}

/// JSON parameter encoding
public struct JSONParameterEncoder: ParameterEncodingStrategy {
    public init() {}
    
    public func encodeBodyParameters(_ parameters: [String: Any]) throws -> Data {
        return try JSONSerialization.data(withJSONObject: parameters)
    }
    
    public func encodeRawBodyData(_ data: Any) throws -> Data {
        return try JSONSerialization.data(withJSONObject: data)
    }
    
    public var contentType: String {
        return ContentType.json.rawValue
    }
}

/// URL-encoded parameter encoding
public struct URLParameterEncoder: ParameterEncodingStrategy {
    public init() {}
    
    public func encodeBodyParameters(_ parameters: [String: Any]) throws -> Data {
        let parameterString = parameters.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let valueString = String(describing: value)
            let encodedValue = valueString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? valueString
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        return parameterString.data(using: .utf8) ?? Data()
    }
    
    public func encodeRawBodyData(_ data: Any) throws -> Data {
        guard let array = data as? [Any] else {
            throw EncodingError.invalidRawData
        }
        
        let parameterString = array.map { value in
            let valueString = String(describing: value)
            return valueString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? valueString
        }.joined(separator: "&")
        return parameterString.data(using: .utf8) ?? Data()
    }
    
    public var contentType: String {
        return ContentType.urlEncoded.rawValue
    }
}

/// Multipart form data parameter encoding
public struct FormDataParameterEncoder: ParameterEncodingStrategy {
    private let boundary: String
    
    public init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }
    
    public func encodeBodyParameters(_ parameters: [String: Any]) throws -> Data {
        return try encodeFormData(parameters: parameters, boundary: boundary)
    }
    
    public func encodeRawBodyData(_ data: Any) throws -> Data {
        guard let array = data as? [Any] else {
            throw EncodingError.invalidRawData
        }
        return try encodeArrayAsFormData(array: array, boundary: boundary)
    }
    
    public var contentType: String {
        return "multipart/form-data; boundary=\(boundary)"
    }
}

/// Custom parameter encoding
public struct CustomParameterEncoder: ParameterEncodingStrategy {
    private let encoder: ([String: Any]) throws -> Data
    private let customContentType: String
    
    public init(encoder: @escaping ([String: Any]) throws -> Data, contentType: String) {
        self.encoder = encoder
        self.customContentType = contentType
    }
    
    public func encodeBodyParameters(_ parameters: [String: Any]) throws -> Data {
        return try encoder(parameters)
    }
    
    public func encodeRawBodyData(_ data: Any) throws -> Data {
        // Wrap raw data in dictionary for custom encoder
        return try encoder(["data": data])
    }
    
    public var contentType: String {
        return customContentType
    }
}

/// Encoding errors
public enum EncodingError: Error {
    case invalidRawData
    case encodingFailed(Error)
}

// MARK: - Private Helper Methods

private extension FormDataParameterEncoder {
    func encodeFormData(parameters: [String: Any], boundary: String) throws -> Data {
        var data = Data()
        
        for (key, value) in parameters {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            
            if let dataValue = value as? Data {
                // Handle file data
                data.append(
                    "Content-Disposition: form-data; name=\"\(key)\"; filename=\"file\"\r\n".data(using: .utf8)!)
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
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
    
    func encodeArrayAsFormData(array: [Any], boundary: String) throws -> Data {
        var data = Data()
        
        for (index, value) in array.enumerated() {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            
            if let dataValue = value as? Data {
                // Handle file data
                data.append(
                    "Content-Disposition: form-data; name=\"\(index)\"; filename=\"file\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                data.append(dataValue)
                data.append("\r\n".data(using: .utf8)!)
            } else {
                // Handle text data
                data.append(
                    "Content-Disposition: form-data; name=\"\(index)\"\r\n\r\n".data(using: .utf8)!)
                data.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
}
