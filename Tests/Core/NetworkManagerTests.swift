import XCTest

@testable import NetworKit

class NetworkManagerTests: XCTestCase {
    var networkManager: NetworkManager!
    var mockSession: MockURLSession!
    var mockProcessor: MockResponseProcessor!
    var mockReachability: MockReachability!
    var mockTokenManager: MockTokenManager!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockProcessor = MockResponseProcessor()
        mockReachability = MockReachability()
        mockTokenManager = MockTokenManager()

        networkManager = NetworkManager(
            session: mockSession,
            responseProcessor: mockProcessor,
            reachability: mockReachability,
            tokenManager: mockTokenManager
        )
    }

    override func tearDown() {
        networkManager = nil
        mockSession = nil
        mockProcessor = nil
        mockReachability = nil
        mockTokenManager = nil
        super.tearDown()
    }

    // MARK: - Request Tests

    func testRequest_WhenNoInternetConnection() {
        // Given
        mockReachability.isConnected = false
        let endpoint = MockEndpoint.simple

        // When
        let expectation = self.expectation(description: "No internet handled")

        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                XCTAssertEqual(error, NetworkError.noInternetConnection)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockSession.dataTaskCallCount, 0, "Should not create data task when offline")
    }

    func testRequest_Success() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.simple
        let expectedModel = MockModel(id: 123, name: "Test")

        mockSession.nextData = "test data".data(using: .utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil,
            headerFields: nil
        )
        mockProcessor.processedResponse = APIResponse.success(value: expectedModel)

        // When
        let expectation = self.expectation(description: "Request success")

        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            // Then
            switch result {
            case .success(let value):
                XCTAssertEqual(value.id, expectedModel.id)
                XCTAssertEqual(value.name, expectedModel.name)
            case .failure:
                XCTFail("Expected success but got failure")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockSession.dataTaskCallCount, 1, "Should create one data task")
        XCTAssertEqual(
            mockSession.lastRequest?.url?.absoluteString, endpoint.baseURL + endpoint.path)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, endpoint.method.rawValue)
        XCTAssertEqual(mockProcessor.processCallCount, 1, "Should process response once")
    }

    func testRequest_APIError() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.simple
        let expectedError = NetworkError.invalidResponse

        mockSession.nextData = "test data".data(using: .utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: 400, httpVersion: nil,
            headerFields: nil
        )
        mockProcessor.processedResponse = APIResponse.failure(error: expectedError)

        // When
        let expectation = self.expectation(description: "Request error")

        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                XCTAssertEqual(error, expectedError)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockSession.dataTaskCallCount, 1, "Should create one data task")
        XCTAssertEqual(mockProcessor.processCallCount, 1, "Should call process")
    }

    func testRequest_URLSessionError() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.simple
        let expectedError = NSError(domain: "test", code: 123, userInfo: nil)

        mockSession.nextError = expectedError

        // When
        let expectation = self.expectation(description: "URLSession error")

        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                XCTAssertEqual(error, NetworkError.requestFailed)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockSession.dataTaskCallCount, 1, "Should create one data task")
    }

    func testRequest_WithRequestModifier() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.withModifier
        let accessToken = "test-token"
        mockTokenManager.mockAccessToken = accessToken

        mockSession.nextData = "test data".data(using: .utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil,
            headerFields: nil
        )
        mockProcessor.processedResponse = APIResponse.success(
            value: MockModel(id: 123, name: "Test"))

        // When
        let expectation = self.expectation(description: "Request with modifier")

        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mockSession.dataTaskCallCount, 1, "Should create one data task")
        XCTAssertEqual(
            mockSession.lastRequest?.allHTTPHeaderFields?["Authorization"], "Bearer \(accessToken)")
        XCTAssertEqual(
            mockSession.lastRequest?.allHTTPHeaderFields?["Custom-Header"], "custom-value")
    }

    func testRequest_WithParameters() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.withParameters

        mockSession.nextData = "test data".data(using: .utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil,
            headerFields: nil
        )
        mockProcessor.processedResponse = APIResponse.success(
            value: MockModel(id: 123, name: "Test"))

        // When
        let expectation = self.expectation(description: "Request with parameters")

        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mockSession.dataTaskCallCount, 1, "Should create one data task")

        // For GET request, parameters should be in URL
        if let url = mockSession.lastRequest?.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        {
            let queryItems = components.queryItems
            XCTAssertTrue(
                queryItems?.contains(where: { $0.name == "param1" && $0.value == "value1" })
                    ?? false)
            XCTAssertTrue(
                queryItems?.contains(where: { $0.name == "param2" && $0.value == "value2" })
                    ?? false)
        } else {
            XCTFail("URL should contain query parameters")
        }
    }

    func testRequest_WithBodyParameters() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.withBodyParameters

        mockSession.nextData = "test data".data(using: .utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil,
            headerFields: nil
        )
        mockProcessor.processedResponse = APIResponse.success(
            value: MockModel(id: 123, name: "Test"))

        // When
        let expectation = self.expectation(description: "Request with body parameters")

        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mockSession.dataTaskCallCount, 1, "Should create one data task")

        // POST request should have parameters in body
        if let httpBody = mockSession.lastRequest?.httpBody,
            let bodyString = String(data: httpBody, encoding: .utf8)
        {
            XCTAssertTrue(bodyString.contains("\"id\":123"))
            XCTAssertTrue(bodyString.contains("\"name\":\"test-name\""))
        } else {
            XCTFail("HTTP body should contain parameters")
        }
    }

    func testRequest_Unauthorized_WithSuccessfulTokenRefresh() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.simple
        let testToken = "refreshed-token"
        let expectedModel = MockModel(id: 123, name: "Test")
        let expectation = self.expectation(description: "Token refresh")

        // First request returns 401
        mockSession.nextData = "unauthorized".data(using: .utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: 401, httpVersion: nil,
            headerFields: nil
        )
        mockProcessor.processedResponse = APIResponse.failure(error: .unauthorized)

        // Configure token manager for successful refresh
        mockTokenManager.refreshCalled = false
        mockTokenManager.refreshCompletionHandler = { completion in
            // Simulate successful token refresh
            self.mockTokenManager.mockAccessToken = testToken

            // Configure data for retry after successful refresh
            self.mockSession.nextData = "success".data(using: .utf8)
            self.mockSession.nextResponse = HTTPURLResponse(
                url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil,
                headerFields: nil)
            self.mockProcessor.processedResponse = APIResponse.success(value: expectedModel)

            completion(.success(()))
        }

        // When
        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            // Then
            switch result {
            case .success(let value):
                XCTAssertEqual(value.id, expectedModel.id)
                XCTAssertEqual(value.name, expectedModel.name)
            case .failure:
                XCTFail("Expected success after token refresh but got failure")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify
        XCTAssertTrue(mockTokenManager.refreshCalled)
        XCTAssertEqual(
            mockSession.dataTaskCallCount, 2, "Should create two data tasks (original + retry)")
        XCTAssertEqual(
            mockSession.lastRequest?.allHTTPHeaderFields?["Authorization"], "Bearer \(testToken)")
    }

    func testRequest_Unauthorized_WithFailedTokenRefresh() {
        // Given
        mockReachability.isConnected = true
        let endpoint = MockEndpoint.simple
        let testToken = "original-token"
        let expectation = self.expectation(description: "Failed token refresh")

        // First request returns 401
        mockTokenManager.mockAccessToken = testToken
        mockSession.nextData = "unauthorized".data(using: .utf8)
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: 401, httpVersion: nil,
            headerFields: nil
        )
        mockProcessor.processedResponse = APIResponse.failure(error: .unauthorized)

        // Configure token manager for failed refresh
        mockTokenManager.refreshCompletionHandler = { completion in
            completion(.failure(.refreshFailed))
        }

        // When
        networkManager.request(endpoint) { (result: APIResponse<MockModel>) in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure(let error):
                XCTAssertEqual(error, NetworkError.unauthorized)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify
        XCTAssertTrue(mockTokenManager.refreshCalled)
        XCTAssertEqual(mockSession.dataTaskCallCount, 1, "Should only create one data task")
    }
}

// MARK: - Mock Classes

enum MockEndpoint: APIEndpoint {
    case simple
    case withModifier
    case withParameters
    case withBodyParameters

    var baseURL: String {
        return "https://example.com"
    }

    var path: String {
        switch self {
        case .simple: return "/test"
        case .withModifier: return "/test-modifier"
        case .withParameters: return "/test-parameters"
        case .withBodyParameters: return "/test-body"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .simple, .withModifier, .withParameters: return .get
        case .withBodyParameters: return .post
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .withParameters: return ["param1": "value1", "param2": "value2"]
        case .withBodyParameters: return ["id": 123, "name": "test-name"]
        default: return nil
        }
    }

    var headers: [String: String]? {
        switch self {
        case .withModifier:
            return ["Custom-Header": "custom-value"]
        default:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .withModifier: return true
        default: return false
        }
    }
}

struct MockModel: Codable, Equatable {
    let id: Int
    let name: String
}

class MockURLSession: URLSessionProtocol {
    var dataTaskCallCount = 0
    var lastRequest: URLRequest?

    var nextData: Data?
    var nextResponse: URLResponse?
    var nextError: Error?

    func dataTask(
        with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    )
        -> URLSessionDataTaskProtocol
    {
        dataTaskCallCount += 1
        lastRequest = request

        return MockURLSessionDataTask { [weak self] in
            completionHandler(self?.nextData, self?.nextResponse, self?.nextError)
        }
    }
}

class MockURLSessionDataTask: URLSessionDataTaskProtocol {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func resume() {
        completion()
    }
}

class MockResponseProcessor: ResponseProcessor {
    var processCallCount = 0
    var processedResponse: APIResponse<Any> = .failure(error: .unknown)

    func process<T>(response: URLResponse?, data: Data?, error: Error?) -> APIResponse<T>
    where T: Decodable {
        processCallCount += 1

        switch processedResponse {
        case .success(let value):
            if let typedValue = value as? T {
                return .success(value: typedValue)
            } else {
                return .failure(error: .decodingFailed)
            }
        case .failure(let error):
            return .failure(error: error)
        }
    }
}

class MockReachability: ReachabilityProtocol {
    var isConnected = true
}

class MockTokenManager: TokenManagerProtocol {
    var mockAccessToken: String?
    var mockRefreshToken: String?
    var refreshCalled = false
    var refreshCompletionHandler: ((Result<Void, NetworkError>) -> Void)? = nil

    func getAccessToken(completion: @escaping (Result<String, NetworkError>) -> Void) {
        if let token = mockAccessToken {
            completion(.success(token))
        } else {
            completion(.failure(.unauthorized))
        }
    }

    func refreshToken(completion: @escaping (Result<Void, NetworkError>) -> Void) {
        refreshCalled = true
        if let handler = refreshCompletionHandler {
            handler(completion)
        } else {
            completion(.failure(.refreshFailed))
        }
    }

    func clearTokens() {
        mockAccessToken = nil
        mockRefreshToken = nil
    }
}
