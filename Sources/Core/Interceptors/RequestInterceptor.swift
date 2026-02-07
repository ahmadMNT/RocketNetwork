//
//  RequestInterceptor.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol for intercepting and modifying requests
public protocol RequestInterceptor {
    /// Called before the request is sent
    func intercept(_ request: inout URLRequest) throws
    
    /// Called after the request is built but before validation
    func postBuild(_ request: inout URLRequest) throws
}

/// Protocol for intercepting responses
public protocol ResponseInterceptor {
    /// Called after response is received
    func intercept(_ response: URLResponse?, data: Data?, error: Error?) throws
}

/// Default no-op interceptor
public struct NoOpInterceptor: RequestInterceptor, ResponseInterceptor {
    public init() {}
    
    public func intercept(_ request: inout URLRequest) throws {
        // No operation
    }
    
    public func postBuild(_ request: inout URLRequest) throws {
        // No operation
    }
    
    public func intercept(_ response: URLResponse?, data: Data?, error: Error?) throws {
        // No operation
    }
}

/// Logging interceptor for debugging
public struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor {
    private let logLevel: LogLevel
    
    public enum LogLevel {
        case none
        case basic
        case detailed
        case headers
        case body
    }
    
    public init(logLevel: LogLevel = .basic) {
        self.logLevel = logLevel
    }
    
    public func intercept(_ request: inout URLRequest) throws {
        guard logLevel != .none else { return }
        
        print("🚀 [Request] \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "no URL")")
        
        if logLevel == .headers || logLevel == .detailed {
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                print("📋 [Headers] \(headers)")
            }
        }
        
        if logLevel == .body || logLevel == .detailed {
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("📦 [Body] \(bodyString)")
            }
        }
    }
    
    public func postBuild(_ request: inout URLRequest) throws {
        // No post-build logging needed for now
    }
    
    public func intercept(_ response: URLResponse?, data: Data?, error: Error?) throws {
        guard logLevel != .none else { return }
        
        if let error = error {
            print("❌ [Error] \(error.localizedDescription)")
            return
        }
        
        if let response = response as? HTTPURLResponse {
            print("📥 [Response] \(response.statusCode) \(response.url?.absoluteString ?? "no URL")")
            
            if logLevel == .headers || logLevel == .detailed {
                print("📋 [Response Headers] \(response.allHeaderFields)")
            }
            
            if logLevel == .body || logLevel == .detailed {
                if let data = data, let dataString = String(data: data, encoding: .utf8) {
                    print("📦 [Response Body] \(dataString)")
                }
            }
        }
    }
}

/// Cache control interceptor
public struct CacheControlInterceptor: RequestInterceptor {
    private let cachePolicy: URLRequest.CachePolicy
    private let timeoutInterval: TimeInterval?
    
    public init(cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval? = nil) {
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
    }
    
    public func intercept(_ request: inout URLRequest) throws {
        request.cachePolicy = cachePolicy
        
        if let timeout = timeoutInterval {
            request.timeoutInterval = timeout
        }
    }
    
    public func postBuild(_ request: inout URLRequest) throws {
        // No post-build modifications needed
    }
}

/// User agent interceptor
public struct UserAgentInterceptor: RequestInterceptor {
    private let userAgent: String
    
    public init(userAgent: String) {
        self.userAgent = userAgent
    }
    
    public func intercept(_ request: inout URLRequest) throws {
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }
    
    public func postBuild(_ request: inout URLRequest) throws {
        // No post-build modifications needed
    }
}

/// Composite interceptor that runs multiple interceptors
public struct CompositeInterceptor: RequestInterceptor, ResponseInterceptor {
    private let requestInterceptors: [RequestInterceptor]
    private let responseInterceptors: [ResponseInterceptor]
    
    public init(
        requestInterceptors: [RequestInterceptor] = [],
        responseInterceptors: [ResponseInterceptor] = []
    ) {
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
    }
    
    public func intercept(_ request: inout URLRequest) throws {
        for interceptor in requestInterceptors {
            try interceptor.intercept(&request)
        }
    }
    
    public func postBuild(_ request: inout URLRequest) throws {
        for interceptor in requestInterceptors {
            try interceptor.postBuild(&request)
        }
    }
    
    public func intercept(_ response: URLResponse?, data: Data?, error: Error?) throws {
        for interceptor in responseInterceptors {
            try interceptor.intercept(response, data: data, error: error)
        }
    }
}
