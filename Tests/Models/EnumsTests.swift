import XCTest
@testable import NetworKit

final class EnumsTests: XCTestCase {
    
    // MARK: - HTTPMethod Tests
    
    func testHTTPMethodRawValues() {
        // Test that HTTP methods have the correct raw values
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.head.rawValue, "HEAD")
    }
    
    // MARK: - ContentType Tests
    
    func testContentTypeRawValues() {
        // Test that content types have the correct raw values
        XCTAssertEqual(ContentType.json.rawValue, "application/json")
        XCTAssertEqual(ContentType.urlEncoded.rawValue, "application/x-www-form-urlencoded")
        XCTAssertEqual(ContentType.multipartFormData.rawValue, "multipart/form-data")
        XCTAssertEqual(ContentType.text.rawValue, "text/plain")
        XCTAssertEqual(ContentType.xml.rawValue, "application/xml")
    }
    
    // MARK: - ParameterEncoding Tests
    
    func testParameterEncodingCases() {
        // Test parameter encoding cases
        let jsonEncoding = ParameterEncoding.json
        let urlEncoding = ParameterEncoding.urlEncoded
        let formDataEncoding = ParameterEncoding.formData(boundary: "boundary-string")
        
        // Test that these initialize correctly
        switch jsonEncoding {
        case .json:
            // Success
            break
        default:
            XCTFail("Expected .json encoding")
        }
        
        switch urlEncoding {
        case .urlEncoded:
            // Success
            break
        default:
            XCTFail("Expected .urlEncoded encoding")
        }
        
        switch formDataEncoding {
        case .formData(let boundary):
            XCTAssertEqual(boundary, "boundary-string")
        default:
            XCTFail("Expected .formData encoding with correct boundary")
        }
        
        // Test custom encoder
        let encoder: ([String: Any]) throws -> Data = { _ in
            return Data()
        }
        let customEncoding = ParameterEncoding.custom(encoder: encoder)
        
        switch customEncoding {
        case .custom:
            // Success
            break
        default:
            XCTFail("Expected .custom encoding")
        }
    }
    
    // MARK: - AuthenticationCredentials Tests
    
    func testAuthenticationCredentialsCases() {
        // Test none case
        let noneAuth = AuthenticationCredentials.none
        XCTAssertEqual(String(describing: noneAuth), "none")
        
        // Test bearer token case
        let bearerAuth = AuthenticationCredentials.bearer(token: "test-token")
        if case .bearer(let token) = bearerAuth {
            XCTAssertEqual(token, "test-token")
        } else {
            XCTFail("Expected bearer token")
        }
        
        // Test basic auth case
        let basicAuth = AuthenticationCredentials.basic(username: "user", password: "pass")
        if case .basic(let username, let password) = basicAuth {
            XCTAssertEqual(username, "user")
            XCTAssertEqual(password, "pass")
        } else {
            XCTFail("Expected basic auth")
        }
        
        // Test API key case
        let apiKeyAuth = AuthenticationCredentials.apiKey(key: "api-key", value: "api-value")
        if case .apiKey(let key, let value) = apiKeyAuth {
            XCTAssertEqual(key, "api-key")
            XCTAssertEqual(value, "api-value")
        } else {
            XCTFail("Expected API key auth")
        }
        
        // Test custom token case
        let customAuth = AuthenticationCredentials.custom(token: "custom-token")
        if case .custom(let token) = customAuth {
            XCTAssertEqual(token, "custom-token")
        } else {
            XCTFail("Expected custom token")
        }
    }
    
    // MARK: - ResponseStatus Tests
    
    func testResponseStatusValues() {
        // Test status code values
        XCTAssertEqual(ResponseStatus.ok, 200)
        XCTAssertEqual(ResponseStatus.created, 201)
        XCTAssertEqual(ResponseStatus.badRequest, 400)
        XCTAssertEqual(ResponseStatus.unauthenticated, 401)
        XCTAssertEqual(ResponseStatus.noPermessions, 403)
        XCTAssertEqual(ResponseStatus.notFound, 404)
        XCTAssertEqual(ResponseStatus.validation, 422)
        XCTAssertEqual(ResponseStatus.upgradeRequired, 426)
        XCTAssertEqual(ResponseStatus.expired, 440)
        XCTAssertEqual(ResponseStatus.serverError, 500)
    }
} 
