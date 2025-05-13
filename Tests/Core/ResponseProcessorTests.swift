import XCTest

@testable import NetworKit

class ResponseProcessorTests: XCTestCase {
    var responseProcessor: ResponseProcessor!

    override func setUp() {
        super.setUp()
        responseProcessor = ResponseProcessor()
    }

    // MARK: - Success Tests

    func testSuccessfulResponse() {
        // Setup
        let jsonData = """
            {
                "name": "Test",
                "id": 123
            }
            """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: jsonData, response: response, error: nil)

        // Assert
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?.name, "Test")
        XCTAssertEqual(result.data?.id, 123)
        XCTAssertNil(result.error)
    }

    func testSuccessfulEmptyResponse() {
        // Setup - empty data with 204 No Content
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )

        // Execute - using Void as the response type since we expect no content
        let result: APIResponse<Void> = responseProcessor.process(
            data: nil, response: response, error: nil)

        // Assert
        XCTAssertTrue(result.isSuccess)
        XCTAssertNil(result.error)
    }

    // MARK: - Error Tests

    func testUnderlyingError() {
        // Setup
        let testError = NSError(domain: "test.error", code: 100, userInfo: nil)

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: nil, response: nil, error: testError)

        // Assert
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.data)

        if case .underlying(let error) = result.error {
            XCTAssertEqual((error as NSError).domain, "test.error")
            XCTAssertEqual((error as NSError).code, 100)
        } else {
            XCTFail("Expected underlying error but got \(String(describing: result.error))")
        }
    }

    func testInvalidResponse() {
        // Setup - no HTTPURLResponse
        let invalidResponse = URLResponse(
            url: URL(string: "https://api.example.com/test")!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: nil, response: invalidResponse, error: nil)

        // Assert
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.data)

        if case .invalidResponse = result.error {
            // Success - correct error type
        } else {
            XCTFail("Expected invalidResponse error but got \(String(describing: result.error))")
        }
    }

    func testUnauthorizedError() {
        // Setup - 401 Unauthorized
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: nil, response: response, error: nil)

        // Assert
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.data)

        if case .unauthorized = result.error {
            // Success - correct error type
        } else {
            XCTFail("Expected unauthorized error but got \(String(describing: result.error))")
        }
    }

    func testServerError() {
        // Setup - 500 Server Error
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        let errorData = """
            {
                "error": "Internal Server Error",
                "message": "Something went wrong"
            }
            """.data(using: .utf8)

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: errorData, response: response, error: nil)

        // Assert
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.data)

        if case .serverError(let statusCode, let errorData) = result.error {
            XCTAssertEqual(statusCode, 500)
            XCTAssertNotNil(errorData)
        } else {
            XCTFail("Expected server error but got \(String(describing: result.error))")
        }
    }

    func testClientError() {
        // Setup - 400 Bad Request
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let errorData = """
            {
                "error": "Bad Request",
                "message": "Invalid parameters"
            }
            """.data(using: .utf8)

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: errorData, response: response, error: nil)

        // Assert
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.data)

        if case .clientError(let statusCode, let errorData) = result.error {
            XCTAssertEqual(statusCode, 400)
            XCTAssertNotNil(errorData)
        } else {
            XCTFail("Expected client error but got \(String(describing: result.error))")
        }
    }

    func testDecodingError() {
        // Setup - valid response but invalid JSON structure for the model
        let invalidJsonData = """
            {
                "invalid": "structure"
            }
            """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: invalidJsonData, response: response, error: nil)

        // Assert
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.data)

        if case .decodingError = result.error {
            // Success - correct error type
        } else {
            XCTFail("Expected decoding error but got \(String(describing: result.error))")
        }
    }

    func testMalformedJson() {
        // Setup - valid response but malformed JSON
        let malformedJsonData = """
            {
                "name": "Test",
                "id": 123,
            }
            """.data(using: .utf8)!

        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Execute
        let result: APIResponse<TestModel> = responseProcessor.process(
            data: malformedJsonData, response: response, error: nil)

        // Assert
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.data)

        if case .malformedJson = result.error {
            // Success - correct error type
        } else {
            XCTFail("Expected malformed JSON error but got \(String(describing: result.error))")
        }
    }

    func testProcessWithError() {
        // Given
        let testError = NSError(domain: "test.error", code: 123, userInfo: nil)

        // When
        let result: Result<String, Error> = responseProcessor.process(
            response: nil, data: nil, error: testError)

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error as NSError):
            XCTAssertEqual(error.domain, testError.domain)
            XCTAssertEqual(error.code, testError.code)
        }
    }

    func testProcessWithInvalidResponse() {
        // Given
        let invalidResponse = URLResponse(
            url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0,
            textEncodingName: nil)

        // When
        let result: Result<String, Error> = responseProcessor.process(
            response: invalidResponse, data: nil, error: nil)

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error as? NetworkError, NetworkError.invalidResponse)
        }
    }

    func testProcessWithUnsuccessfulStatusCode() {
        // Given
        let statusCodes = [400, 401, 403, 404, 500, 502, 503]

        for statusCode in statusCodes {
            // Given
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )

            // When
            let result: Result<String, Error> = responseProcessor.process(
                response: response, data: nil, error: nil)

            // Then
            switch result {
            case .success:
                XCTFail("Expected failure for status code \(statusCode)")
            case .failure(let error):
                switch statusCode {
                case 401:
                    XCTAssertEqual(error as? NetworkError, NetworkError.unauthorized)
                case 404:
                    XCTAssertEqual(error as? NetworkError, NetworkError.notFound)
                case 400, 403:
                    XCTAssertEqual(error as? NetworkError, NetworkError.badRequest)
                case 500, 502, 503:
                    XCTAssertEqual(error as? NetworkError, NetworkError.serverError)
                default:
                    XCTFail("Unexpected status code \(statusCode)")
                }
            }
        }
    }

    func testProcessWithMissingData() {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // When
        let result: Result<String, Error> = responseProcessor.process(
            response: response, data: nil, error: nil)

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error as? NetworkError, NetworkError.noData)
        }
    }

    func testProcessWithNonDecodableData() {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let invalidJSON = "{ invalid json }".data(using: .utf8)!

        // When
        let result: Result<TestModel, Error> = responseProcessor.process(
            response: response, data: invalidJSON, error: nil)

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error as? NetworkError, NetworkError.decodingFailed)
        }
    }

    func testProcessWithValidDecodableData() {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let validJSON = """
            {
                "id": 123,
                "name": "Test Model"
            }
            """.data(using: .utf8)!

        // When
        let result: Result<TestModel, Error> = responseProcessor.process(
            response: response, data: validJSON, error: nil)

        // Then
        switch result {
        case .success(let model):
            XCTAssertEqual(model.id, 123)
            XCTAssertEqual(model.name, "Test Model")
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testProcessWithStringData() {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let stringData = "Test String".data(using: .utf8)!

        // When
        let result: Result<String, Error> = responseProcessor.process(
            response: response, data: stringData, error: nil)

        // Then
        switch result {
        case .success(let string):
            XCTAssertEqual(string, "Test String")
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testProcessWithRawData() {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let testData = "Test Data".data(using: .utf8)!

        // When
        let result: Result<Data, Error> = responseProcessor.process(
            response: response, data: testData, error: nil)

        // Then
        switch result {
        case .success(let data):
            XCTAssertEqual(data, testData)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
}

// MARK: - Test Models

struct TestModel: Codable {
    let name: String
    let id: Int
}
