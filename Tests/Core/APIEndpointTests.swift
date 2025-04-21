import XCTest
@testable import NetworKit

final class APIEndpointTests: XCTestCase {
    
    // MARK: - Mock Endpoint
    
    // Create a simple mock endpoint that conforms to APIEndpoint
    struct MockEndpoint: APIEndpoint {
        var host: String { return "api.example.com" }
        var path: String { return "/test/endpoint" }
        var method: HTTPMethod { return .get }
        var queryParameters: [URLQueryItem] { return [URLQueryItem(name: "test", value: "value")] }
        var bodyParameters: [String: Any]? { return ["key": "value"] }
        
        // Using default implementations for remaining properties
    }
    
    // Create a more customized mock endpoint
    struct CustomizedMockEndpoint: APIEndpoint {
        var scheme: String { return "http" }
        var host: String { return "test.example.com" }
        var port: Int? { return 8080 }
        var path: String { return "/custom/path" }
        var method: HTTPMethod { return .post }
        var timeout: TimeInterval { return 60.0 }
        var encoding: ParameterEncoding { return .urlEncoded }
        var contentType: ContentType { return .urlEncoded }
        var accept: ContentType { return .xml }
        var retryCount: Int { return 3 }
        var queryParameters: [URLQueryItem] { return [URLQueryItem(name: "custom", value: "param")] }
        var bodyParameters: [String: Any]? { return ["data": "custom value"] }
        var headers: [String: String] { return ["X-Custom-Header": "custom-value"] }
        var authenticationCredentials: AuthenticationCredentials { 
            return .bearer(token: "test-token") 
        }
    }
    
    // MARK: - Tests
    
    func testDefaultBaseURL() {
        let endpoint = MockEndpoint()
        XCTAssertEqual(endpoint.baseURL.absoluteString, "https://api.example.com")
    }
    
    func testCustomizedBaseURL() {
        let endpoint = CustomizedMockEndpoint()
        XCTAssertEqual(endpoint.baseURL.absoluteString, "http://test.example.com:8080")
    }
    
    func testDefaultImplementations() {
        let endpoint = MockEndpoint()
        
        // Check default property values
        XCTAssertEqual(endpoint.scheme, "https")
        XCTAssertNil(endpoint.port)
        XCTAssertEqual(endpoint.timeout, 30.0)
        XCTAssertEqual(endpoint.retryCount, 1)
        XCTAssertTrue(endpoint.headers.isEmpty)
        
        if case .json = endpoint.encoding {
            // Success
        } else {
            XCTFail("Default encoding should be JSON")
        }
        
        if case .json = endpoint.contentType {
            // Success
        } else {
            XCTFail("Default content type should be JSON")
        }
        
        if case .json = endpoint.accept {
            // Success
        } else {
            XCTFail("Default accept type should be JSON")
        }
        
        if case .none = endpoint.authenticationCredentials {
            // Success
        } else {
            XCTFail("Default authentication credentials should be none")
        }
    }
    
    func testBuildURLRequest() {
        let endpoint = MockEndpoint()
        let request = endpoint.buildURLRequest()
        
        // Check URL
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/test/endpoint?test=value")
        
        // Check method
        XCTAssertEqual(request.httpMethod, "GET")
        
        // Check timeout
        XCTAssertEqual(request.timeoutInterval, 30.0)
        
        // Check headers
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        
        // For GET requests, there should be no body
        XCTAssertNil(request.httpBody)
    }
    
    func testBuildURLRequestWithCustomization() {
        let endpoint = CustomizedMockEndpoint()
        let request = endpoint.buildURLRequest()
        
        // Check URL
        XCTAssertEqual(request.url?.absoluteString, "http://test.example.com:8080/custom/path?custom=param")
        
        // Check method
        XCTAssertEqual(request.httpMethod, "POST")
        
        // Check timeout
        XCTAssertEqual(request.timeoutInterval, 60.0)
        
        // Check headers
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/xml")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom-Header"), "custom-value")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        
        // For POST requests with urlEncoded encoding, check body content
        XCTAssertNotNil(request.httpBody)
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            XCTAssertEqual(bodyString, "data=custom%20value")
        } else {
            XCTFail("Failed to decode request body")
        }
    }
    
    func testAuthorizationHeaders() {
        // Test bearer token
        let bearerAuth = AuthenticationCredentials.bearer(token: "bearer-token")
        let bearerHeaders = getAuthorizationHeaders(for: bearerAuth)
        XCTAssertEqual(bearerHeaders?["Authorization"], "Bearer bearer-token")
        
        // Test basic auth
        let basicAuth = AuthenticationCredentials.basic(username: "user", password: "pass")
        let basicHeaders = getAuthorizationHeaders(for: basicAuth)
        XCTAssertTrue(basicHeaders?["Authorization"]?.hasPrefix("Basic ") ?? false)
        
        // Test API key
        let apiKeyAuth = AuthenticationCredentials.apiKey(key: "X-API-Key", value: "key-value")
        let apiKeyHeaders = getAuthorizationHeaders(for: apiKeyAuth)
        XCTAssertEqual(apiKeyHeaders?["X-API-Key"], "key-value")
        
        // Test custom token
        let customAuth = AuthenticationCredentials.custom(token: "custom-token")
        let customHeaders = getAuthorizationHeaders(for: customAuth)
        XCTAssertEqual(customHeaders?["Authorization"], "Basic custom-token")
        
        // Test none
        let noneAuth = AuthenticationCredentials.none
        let noneHeaders = getAuthorizationHeaders(for: noneAuth)
        XCTAssertNil(noneHeaders)
    }
    
    // Helper function to get authorization headers
    private func getAuthorizationHeaders(for credentials: AuthenticationCredentials) -> [String: String]? {
        struct TestEndpoint: APIEndpoint {
            let authCredentials: AuthenticationCredentials
            var host: String { return "example.com" }
            var path: String { return "/test" }
            var authenticationCredentials: AuthenticationCredentials { return authCredentials }
        }
        
        let endpoint = TestEndpoint(authCredentials: credentials)
        return endpoint.getAuthorization()
    }
} 
