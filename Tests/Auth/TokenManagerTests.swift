import XCTest

@testable import NetworKit

class AuthTokenManagerTests: XCTestCase {
    var tokenManager: AuthTokenManager!
    var mockStorage: MockTokenStorage!
    var mockApiClient: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockStorage = MockTokenStorage()
        mockApiClient = MockAPIClient()
        tokenManager = AuthTokenManager(
            tokenStorage: mockStorage,
            apiClient: mockApiClient
        )
    }

    func testGetAccessToken_WithValidToken() {
        // Given
        let accessToken = "valid-access-token"
        mockStorage.accessToken = accessToken

        // When
        let expectation = self.expectation(description: "Access token retrieved")
        var resultToken: String?
        var resultError: Error?

        tokenManager.getAccessToken { result in
            switch result {
            case .success(let token):
                resultToken = token
            case .failure(let error):
                resultError = error
            }
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(resultToken, accessToken)
        XCTAssertNil(resultError)
        XCTAssertEqual(
            mockApiClient.refreshCallCount, 0, "Should not attempt to refresh a valid token")
    }

    func testGetAccessToken_WithNoToken_RefreshSuccess() {
        // Given
        mockStorage.accessToken = nil
        mockStorage.refreshToken = "valid-refresh-token"
        let newAccessToken = "new-access-token"
        let newRefreshToken = "new-refresh-token"

        mockApiClient.refreshResult = .success((newAccessToken, newRefreshToken))

        // When
        let expectation = self.expectation(description: "Token refreshed")
        var resultToken: String?
        var resultError: Error?

        tokenManager.getAccessToken { result in
            switch result {
            case .success(let token):
                resultToken = token
            case .failure(let error):
                resultError = error
            }
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(resultToken, newAccessToken)
        XCTAssertNil(resultError)
        XCTAssertEqual(
            mockApiClient.refreshCallCount, 1, "Should attempt to refresh when no access token")
        XCTAssertEqual(mockStorage.accessToken, newAccessToken, "Should store new access token")
        XCTAssertEqual(mockStorage.refreshToken, newRefreshToken, "Should store new refresh token")
    }

    func testGetAccessToken_WithNoToken_NoRefreshToken() {
        // Given
        mockStorage.accessToken = nil
        mockStorage.refreshToken = nil

        // When
        let expectation = self.expectation(description: "No token handled")
        var resultToken: String?
        var resultError: Error?

        tokenManager.getAccessToken { result in
            switch result {
            case .success(let token):
                resultToken = token
            case .failure(let error):
                resultError = error
            }
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertNil(resultToken)
        XCTAssertNotNil(resultError)
        XCTAssertEqual(
            resultError as? NetworkError, NetworkError.unauthenticated,
            "Should return unauthorized when no tokens")
        XCTAssertEqual(
            mockApiClient.refreshCallCount, 0, "Should not attempt to refresh when no refresh token"
        )
    }

    func testGetAccessToken_WithNoToken_RefreshFailure() {
        // Given
        mockStorage.accessToken = nil
        mockStorage.refreshToken = "valid-refresh-token"
        let refreshError = NetworkError.serverError(statusCode: 500)

        mockApiClient.refreshResult = .failure(refreshError)

        // When
        let expectation = self.expectation(description: "Refresh failure handled")
        var resultToken: String?
        var resultError: Error?

        tokenManager.getAccessToken { result in
            switch result {
            case .success(let token):
                resultToken = token
            case .failure(let error):
                resultError = error
            }
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertNil(resultToken)
        XCTAssertNotNil(resultError)
        XCTAssertEqual(
            (resultError as? NetworkError)?.localizedDescription, refreshError.localizedDescription,
            "Should return refresh error")
        XCTAssertEqual(mockApiClient.refreshCallCount, 1, "Should attempt to refresh token")
    }

    func testRefreshToken_Success() {
        // Given
        let refreshToken = "valid-refresh-token"
        mockStorage.refreshToken = refreshToken
        let newAccessToken = "new-access-token"
        let newRefreshToken = "new-refresh-token"

        mockApiClient.refreshResult = .success((newAccessToken, newRefreshToken))

        // When
        let expectation = self.expectation(description: "Token refreshed")
        var resultSuccess = false
        var resultError: Error?

        tokenManager.refreshToken { result in
            switch result {
            case .success:
                resultSuccess = true
            case .failure(let error):
                resultError = error
            }
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(resultSuccess)
        XCTAssertNil(resultError)
        XCTAssertEqual(mockApiClient.refreshCallCount, 1, "Should call refresh API")
        XCTAssertEqual(
            mockApiClient.lastRefreshToken, refreshToken, "Should use stored refresh token")
        XCTAssertEqual(mockStorage.accessToken, newAccessToken, "Should store new access token")
        XCTAssertEqual(mockStorage.refreshToken, newRefreshToken, "Should store new refresh token")
    }

    func testRefreshToken_NoRefreshToken() {
        // Given
        mockStorage.refreshToken = nil

        // When
        let expectation = self.expectation(description: "No refresh token handled")
        var resultSuccess = false
        var resultError: Error?

        tokenManager.refreshToken { result in
            switch result {
            case .success:
                resultSuccess = true
            case .failure(let error):
                resultError = error
            }
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertFalse(resultSuccess)
        XCTAssertNotNil(resultError)
        XCTAssertEqual(
            resultError as? NetworkError, NetworkError.unauthenticated,
            "Should return unauthorized when no refresh token")
        XCTAssertEqual(
            mockApiClient.refreshCallCount, 0, "Should not call API with no refresh token")
    }

    func testRefreshToken_ApiFailure() {
        // Given
        mockStorage.refreshToken = "valid-refresh-token"
        let refreshError = NetworkError.serverError(statusCode: 500)

        mockApiClient.refreshResult = .failure(refreshError)

        // When
        let expectation = self.expectation(description: "API failure handled")
        var resultSuccess = false
        var resultError: Error?

        tokenManager.refreshToken { result in
            switch result {
            case .success:
                resultSuccess = true
            case .failure(let error):
                resultError = error
            }
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertFalse(resultSuccess)
        XCTAssertNotNil(resultError)
        XCTAssertEqual(
            (resultError as? NetworkError)?.localizedDescription, refreshError.localizedDescription,
            "Should return API error")
        XCTAssertEqual(mockApiClient.refreshCallCount, 1, "Should call refresh API")
    }

    func testClearTokens() {
        // Given
        mockStorage.accessToken = "access-token"
        mockStorage.refreshToken = "refresh-token"

        // When
        tokenManager.clearTokens()

        // Then
        XCTAssertNil(mockStorage.accessToken, "Access token should be cleared")
        XCTAssertNil(mockStorage.refreshToken, "Refresh token should be cleared")
    }
}

// MARK: - Mock Classes

class MockTokenStorage: TokenStorage {
    var accessToken: String?
    var refreshToken: String?

    func getAccessToken() -> String? {
        return accessToken
    }

    func getRefreshToken() -> String? {
        return refreshToken
    }

    func storeAccessToken(_ token: String?) {
        accessToken = token
    }

    func storeRefreshToken(_ token: String?) {
        refreshToken = token
    }
}

class MockAPIClient: AuthAPIClient {
    var refreshCallCount = 0
    var lastRefreshToken: String?
    var refreshResult: Result<(String, String), Error> = .failure(NetworkError.unknownError)

    func refreshTokens(
        refreshToken: String, completion: @escaping (Result<(String, String), Error>) -> Void
    ) {
        refreshCallCount += 1
        lastRefreshToken = refreshToken
        completion(refreshResult)
    }
}
