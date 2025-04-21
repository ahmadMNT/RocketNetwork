//
//  NetworkLogger.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for logging network activity
public protocol NetworkLogger {
    /// Log an HTTP request
    /// - Parameter request: The URLRequest to log
    func logRequest(_ request: URLRequest)
    
    /// Log an HTTP response
    /// - Parameters:
    ///   - response: The URLResponse to log
    ///   - data: The response data, if available
    func logResponse(_ response: URLResponse, data: Data?)
    
    /// Log a network error
    /// - Parameter error: The error to log
    func logError(_ error: Error)
}

/// Log levels for network logging
public enum LogLevel: Int {
    /// No logging
    case none = 0
    
    /// Log errors only
    case errors = 1
    
    /// Log basic request/response info
    case info = 2
    
    /// Log detailed request/response info including headers
    case debug = 3
    
    /// Log everything including request/response bodies
    case verbose = 4
}

/// Default implementation of NetworkLogger
public class DefaultNetworkLogger: NetworkLogger {
    private let logLevel: LogLevel
    
    /// Initialize with a log level
    /// - Parameter logLevel: The desired log level
    public init(logLevel: LogLevel = .info) {
        self.logLevel = logLevel
    }
    
    public func logRequest(_ request: URLRequest) {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        
        print("📤 REQUEST: \(request.httpMethod ?? "Unknown") \(request.url?.absoluteString ?? "Unknown URL")")
        
        if logLevel.rawValue >= LogLevel.debug.rawValue {
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                print("📋 HEADERS: \(headers)")
            }
        }
        
        if logLevel.rawValue >= LogLevel.verbose.rawValue {
            if let body = request.httpBody {
                if let json = tryFormatJSON(data: body) {
                    print("📦 BODY: \(json)")
                } else if let bodyString = String(data: body, encoding: .utf8) {
                    print("📦 BODY: \(bodyString)")
                }
            }
        }
    }
    
    public func logResponse(_ response: URLResponse, data: Data?) {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        
        if let httpResponse = response as? HTTPURLResponse {
            let statusEmoji = httpResponse.statusCode >= 400 ? "❌" : "✅"
            print("\(statusEmoji) RESPONSE: \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "Unknown URL")")
            
            if logLevel.rawValue >= LogLevel.debug.rawValue {
                print("⏱️ TIME: \(Date())")
            }
            
            if logLevel.rawValue >= LogLevel.verbose.rawValue, let data = data {
                if let json = tryFormatJSON(data: data) {
                    print("📦 RESPONSE DATA: \(json)")
                } else if let string = String(data: data, encoding: .utf8) {
                    print("📦 RESPONSE DATA: \(string)")
                }
            }
        }
    }
    
    public func logError(_ error: Error) {
        guard logLevel.rawValue >= LogLevel.errors.rawValue else { return }
        
        if let networkError = error as? NetworkError {
            print("🛑 NETWORK ERROR: \(networkError.message)")
        } else {
            print("🛑 ERROR: \(error.localizedDescription)")
        }
    }
    
    // Helper to format JSON data for prettier logging
    private func tryFormatJSON(data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }
} 
