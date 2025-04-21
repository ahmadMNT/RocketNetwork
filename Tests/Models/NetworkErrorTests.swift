import XCTest
@testable import NetworKit

final class NetworkErrorTests: XCTestCase {
    
    func testErrorMessageProvided() {
        // Test that all error types provide a non-empty error message
        let errors: [NetworkError] = [
            .invalidResponse,
            .unauthenticated,
            .tokenExpired,
            .decodingError(NSError(domain: "test", code: 1, userInfo: nil)),
            .serverError(statusCode: 500),
            .serverMessage(message: "Server message"),
            .validationError(message: "Validation error"),
            .notFound,
            .maxRetriesExceeded,
            .canceled,
            .forbidden,
            .appUpdateRequired,
            .noInternetConnection,
            .requestTimedOut,
            .badRequest,
            .unknownError
        ]
        
        for error in errors {
            XCTAssertFalse(error.message.isEmpty, "Error type \(error) should provide a message")
        }
    }
    
    func testErrorTypeClassification() {
        // Test unauthenticated error type
        XCTAssertEqual(NetworkError.unauthenticated.errorType, .unauthenticated)
        XCTAssertEqual(NetworkError.tokenExpired.errorType, .unauthenticated)
        
        // Test forbidden error type
        XCTAssertEqual(NetworkError.forbidden.errorType, .forbidden)
        
        // Test upgrade required error type
        XCTAssertEqual(NetworkError.appUpdateRequired.errorType, .upgradeRequired)
        
        // Test connectivity error types
        XCTAssertEqual(NetworkError.noInternetConnection.errorType, .connectivity)
        XCTAssertEqual(NetworkError.requestTimedOut.errorType, .connectivity)
        
        // Test general error types
        XCTAssertEqual(NetworkError.invalidResponse.errorType, .general)
        XCTAssertEqual(NetworkError.serverError(statusCode: 500).errorType, .general)
        XCTAssertEqual(NetworkError.notFound.errorType, .general)
    }
    
    func testEquality() {
        // Test same error types are equal
        XCTAssertEqual(NetworkError.invalidResponse, NetworkError.invalidResponse)
        XCTAssertEqual(NetworkError.unauthenticated, NetworkError.unauthenticated)
        XCTAssertEqual(NetworkError.serverError(statusCode: 500), NetworkError.serverError(statusCode: 500))
        
        // Test different error types are not equal
        XCTAssertNotEqual(NetworkError.invalidResponse, NetworkError.unauthenticated)
        XCTAssertNotEqual(NetworkError.serverError(statusCode: 500), NetworkError.serverError(statusCode: 404))
        XCTAssertNotEqual(NetworkError.serverMessage(message: "Error 1"), NetworkError.serverMessage(message: "Error 2"))
        
        // Test errors with associated values
        let error1 = NSError(domain: "test", code: 1, userInfo: nil)
        let error2 = NSError(domain: "test", code: 2, userInfo: nil)
        
        // Decoding errors cannot be compared for equality due to the Error protocol not conforming to Equatable
        XCTAssertNotEqual(NetworkError.decodingError(error1), NetworkError.decodingError(error2))
    }
} 
