import XCTest

@testable import NetworKit

class TokenManagerTests: XCTestCase {
    var tokenManager: TokenManager!
    var mockUserDefaults: MockUserDefaults!

    override func setUp() {
        super.setUp()
        mockUserDefaults = MockUserDefaults()
        tokenManager = TokenManager(userDefaults: mockUserDefaults)
    }

    func testSaveAndRetrieveAccessToken() {
        // Given
        let testToken = "test-access-token"

        // When
        tokenManager.saveAccessToken(testToken)
        let retrievedToken = tokenManager.accessToken

        // Then
        XCTAssertEqual(retrievedToken, testToken)
        XCTAssertEqual(
            mockUserDefaults.savedValues[TokenManager.Constants.accessTokenKey] as? String,
            testToken)
    }

    func testSaveAndRetrieveRefreshToken() {
        // Given
        let testToken = "test-refresh-token"

        // When
        tokenManager.saveRefreshToken(testToken)
        let retrievedToken = tokenManager.refreshToken

        // Then
        XCTAssertEqual(retrievedToken, testToken)
        XCTAssertEqual(
            mockUserDefaults.savedValues[TokenManager.Constants.refreshTokenKey] as? String,
            testToken)
    }

    func testClearTokens() {
        // Given
        tokenManager.saveAccessToken("test-access-token")
        tokenManager.saveRefreshToken("test-refresh-token")

        // When
        tokenManager.clearTokens()

        // Then
        XCTAssertNil(tokenManager.accessToken)
        XCTAssertNil(tokenManager.refreshToken)
        XCTAssertNil(mockUserDefaults.savedValues[TokenManager.Constants.accessTokenKey])
        XCTAssertNil(mockUserDefaults.savedValues[TokenManager.Constants.refreshTokenKey])
    }

    func testHasValidAccessToken_WithValidToken() {
        // Given
        tokenManager.saveAccessToken("test-access-token")

        // When
        let hasValidToken = tokenManager.hasValidAccessToken

        // Then
        XCTAssertTrue(hasValidToken)
    }

    func testHasValidAccessToken_WithNilToken() {
        // Given
        tokenManager.clearTokens()

        // When
        let hasValidToken = tokenManager.hasValidAccessToken

        // Then
        XCTAssertFalse(hasValidToken)
    }

    func testHasValidAccessToken_WithEmptyToken() {
        // Given
        tokenManager.saveAccessToken("")

        // When
        let hasValidToken = tokenManager.hasValidAccessToken

        // Then
        XCTAssertFalse(hasValidToken)
    }

    func testHasValidRefreshToken_WithValidToken() {
        // Given
        tokenManager.saveRefreshToken("test-refresh-token")

        // When
        let hasValidToken = tokenManager.hasValidRefreshToken

        // Then
        XCTAssertTrue(hasValidToken)
    }

    func testHasValidRefreshToken_WithNilToken() {
        // Given
        tokenManager.clearTokens()

        // When
        let hasValidToken = tokenManager.hasValidRefreshToken

        // Then
        XCTAssertFalse(hasValidToken)
    }

    func testHasValidRefreshToken_WithEmptyToken() {
        // Given
        tokenManager.saveRefreshToken("")

        // When
        let hasValidToken = tokenManager.hasValidRefreshToken

        // Then
        XCTAssertFalse(hasValidToken)
    }

    func testRefreshToken_Success() {
        // Given
        let expectation = self.expectation(description: "Token refresh completed")

        let mockSession = MockURLSession()
        let refreshToken = "test-refresh-token"
        tokenManager.saveRefreshToken(refreshToken)

        let expectedAccessToken = "new-access-token"
        let expectedRefreshToken = "new-refresh-token"

        let responseJSON = """
            {
                "access_token": "\(expectedAccessToken)",
                "refresh_token": "\(expectedRefreshToken)"
            }
            """.data(using: .utf8)!

        mockSession.nextData = responseJSON
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com/refresh")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // When
        tokenManager.refreshToken(
            using: mockSession, with: URL(string: "https://api.example.com/refresh")!
        ) { result in
            // Then
            switch result {
            case .success:
                XCTAssertEqual(self.tokenManager.accessToken, expectedAccessToken)
                XCTAssertEqual(self.tokenManager.refreshToken, expectedRefreshToken)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)

        // Verify request was made correctly
        XCTAssertEqual(
            mockSession.lastRequest?.url?.absoluteString, "https://api.example.com/refresh")
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")

        // Verify refresh token was included in request
        if let httpBody = mockSession.lastRequest?.httpBody,
            let bodyString = String(data: httpBody, encoding: .utf8)
        {
            XCTAssertTrue(bodyString.contains(refreshToken))
        } else {
            XCTFail("Expected HTTP body with refresh token")
        }
    }

    func testRefreshToken_Failure() {
        // Given
        let expectation = self.expectation(description: "Token refresh failed")

        let mockSession = MockURLSession()
        tokenManager.saveRefreshToken("test-refresh-token")

        mockSession.nextError = NSError(domain: "test.error", code: 500, userInfo: nil)

        // When
        tokenManager.refreshToken(
            using: mockSession, with: URL(string: "https://api.example.com/refresh")!
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure but got success")
            case .failure:
                // Success - we expected an error
                break
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }
}

// MARK: - Mock Classes

class MockUserDefaults: UserDefaults {
    var savedValues: [String: Any] = [:]

    override func set(_ value: Any?, forKey defaultName: String) {
        savedValues[defaultName] = value
    }

    override func object(forKey defaultName: String) -> Any? {
        return savedValues[defaultName]
    }

    override func removeObject(forKey defaultName: String) {
        savedValues.removeValue(forKey: defaultName)
    }
}

class MockURLSession: URLSession {
    var nextData: Data?
    var nextResponse: URLResponse?
    var nextError: Error?

    var lastRequest: URLRequest?
    var lastCompletionHandler: ((Data?, URLResponse?, Error?) -> Void)?

    override func dataTask(
        with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    )
        -> URLSessionDataTask
    {
        lastRequest = request
        lastCompletionHandler = completionHandler

        let task = MockURLSessionDataTask {
            completionHandler(self.nextData, self.nextResponse, self.nextError)
        }
        return task
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    private let resumeAction: () -> Void

    init(resumeAction: @escaping () -> Void) {
        self.resumeAction = resumeAction
        super.init()
    }

    override func resume() {
        resumeAction()
    }
}
