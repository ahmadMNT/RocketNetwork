import XCTest

@testable import NetworKit

final class APIResponseTests: XCTestCase {
    struct TestModel: Decodable, Equatable {
        let id: Int
        let name: String
    }

    func testInitialization() {
        // Test initialization with all parameters
        let testModel = TestModel(id: 1, name: "Test")
        let response = APIResponse<TestModel>(
            success: true,
            message: "Success message",
            data: testModel,
            statusCode: 200
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Success message")
        XCTAssertEqual(response.data, testModel)
        XCTAssertEqual(response.statusCode, 200)

        // Test initialization with default values
        let responseWithDefaults = APIResponse<TestModel>(success: false)
        XCTAssertFalse(responseWithDefaults.success)
        XCTAssertNil(responseWithDefaults.message)
        XCTAssertNil(responseWithDefaults.data)
        XCTAssertNil(responseWithDefaults.statusCode)
    }

    func testErrorMessage() {
        // Test with message
        let response1 = APIResponse<TestModel>(success: false, message: "Error message")
        XCTAssertEqual(response1.errorMessage, "Error message")

        // Test without message (should return default)
        let response2 = APIResponse<TestModel>(success: false)
        XCTAssertEqual(response2.errorMessage, "Unknown error occurred")
    }

    func testHasData() {
        // Test with data
        let modelWithData = APIResponse<TestModel>(
            success: true,
            data: TestModel(id: 1, name: "Test")
        )
        XCTAssertTrue(modelWithData.hasData)

        // Test without data
        let modelWithoutData = APIResponse<TestModel>(success: true)
        XCTAssertFalse(modelWithoutData.hasData)
    }

    func testMapFunction() {
        // Create an APIResponse with TestModel
        let testModel = TestModel(id: 1, name: "Test")
        let response = APIResponse<TestModel>(
            success: true,
            message: "Success",
            data: testModel,
            statusCode: 200
        )

        // Map the response to String
        let mappedResponse = response.map { model in
            return model.name
        }

        // Verify the mapped response
        XCTAssertTrue(mappedResponse.success)
        XCTAssertEqual(mappedResponse.message, "Success")
        XCTAssertEqual(mappedResponse.data, "Test")
        XCTAssertEqual(mappedResponse.statusCode, 200)
    }

    func testStaticFactoryMethods() {
        // Test the failure factory method
        let failureResponse = APIResponse<TestModel>.failure(message: "Error occurred")
        XCTAssertFalse(failureResponse.success)
        XCTAssertEqual(failureResponse.message, "Error occurred")
        XCTAssertNil(failureResponse.data)
        XCTAssertNil(failureResponse.statusCode)

        // Test the success factory method
        let testModel = TestModel(id: 1, name: "Test")
        let successResponse = APIResponse<TestModel>.success(data: testModel)
        XCTAssertTrue(successResponse.success)
        XCTAssertNil(successResponse.message)
        XCTAssertEqual(successResponse.data, testModel)
        XCTAssertEqual(successResponse.statusCode, 200)
    }

    func testDecoding() throws {
        // JSON string representing a successful response
        let jsonString = """
            {
                "Success": true,
                "Message": "Operation successful",
                "Data": {
                    "id": 1,
                    "name": "Test Model"
                },
                "StatusCode": 200
            }
            """

        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()

        // Decode JSON into APIResponse<TestModel>
        let response = try decoder.decode(APIResponse<TestModel>.self, from: jsonData)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Operation successful")
        XCTAssertEqual(response.data?.id, 1)
        XCTAssertEqual(response.data?.name, "Test Model")
        XCTAssertEqual(response.statusCode, 200)
    }
}
