//
//  ErrorModelTests.swift
//  RocketTests
//
//  Created as part of the Rocket module.
//

import XCTest
@testable import Rocket

final class ErrorModelTests: XCTestCase {
    
    // MARK: - DefaultErrorModel Tests
    
    func testDefaultErrorModelInitialization() {
        let errorModel = DefaultErrorModel(
            message: "Test error",
            code: "TEST_ERROR",
            details: ["Detail 1", "Detail 2"],
            fieldErrors: ["field1": ["Error 1", "Error 2"]]
        )
        
        XCTAssertEqual(errorModel.message, "Test error")
        XCTAssertEqual(errorModel.code, "TEST_ERROR")
        XCTAssertEqual(errorModel.details, ["Detail 1", "Detail 2"])
        XCTAssertEqual(errorModel.fieldErrors?["field1"], ["Error 1", "Error 2"])
    }
    
    func testDefaultErrorModelSimpleInitialization() {
        let errorModel = DefaultErrorModel(message: "Simple error")
        
        XCTAssertEqual(errorModel.message, "Simple error")
        XCTAssertNil(errorModel.code)
        XCTAssertNil(errorModel.details)
        XCTAssertNil(errorModel.fieldErrors)
    }
    
    func testDefaultErrorModelDecoding() throws {
        let jsonData = """
        {
            "message": "Test error",
            "code": "TEST_ERROR",
            "details": ["Detail 1"],
            "field_errors": {
                "field1": ["Error 1"]
            }
        }
        """.data(using: .utf8)!
        
        let errorModel = try JSONDecoder().decode(DefaultErrorModel.self, from: jsonData)
        
        XCTAssertEqual(errorModel.message, "Test error")
        XCTAssertEqual(errorModel.code, "TEST_ERROR")
        XCTAssertEqual(errorModel.details, ["Detail 1"])
        XCTAssertEqual(errorModel.fieldErrors?["field1"], ["Error 1"])
    }
    
    func testDefaultErrorModelDecodingWithAlternativeKeys() throws {
        let jsonData = """
        {
            "error": "Alternative error",
            "errors": {
                "field2": ["Alternative error"]
            }
        }
        """.data(using: .utf8)!
        
        let errorModel = try JSONDecoder().decode(DefaultErrorModel.self, from: jsonData)
        
        XCTAssertEqual(errorModel.message, "Alternative error")
        XCTAssertEqual(errorModel.fieldErrors?["field2"], ["Alternative error"])
    }
    
    func testDefaultErrorModelEquality() {
        let error1 = DefaultErrorModel(
            message: "Test error",
            code: "TEST_ERROR",
            details: ["Detail 1"],
            fieldErrors: ["field1": ["Error 1"]]
        )
        
        let error2 = DefaultErrorModel(
            message: "Test error",
            code: "TEST_ERROR",
            details: ["Detail 1"],
            fieldErrors: ["field1": ["Error 1"]]
        )
        
        let error3 = DefaultErrorModel(message: "Different error")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    func testDefaultErrorModelDescription() {
        let errorModel = DefaultErrorModel(
            message: "Test error",
            code: "TEST_ERROR",
            details: ["Detail 1", "Detail 2"],
            fieldErrors: ["field1": ["Error 1"], "field2": ["Error 2"]]
        )
        
        let description = errorModel.description
        
        XCTAssertTrue(description.contains("Test error"))
        XCTAssertTrue(description.contains("TEST_ERROR"))
        XCTAssertTrue(description.contains("Detail 1"))
        XCTAssertTrue(description.contains("Detail 2"))
        XCTAssertTrue(description.contains("field1"))
        XCTAssertTrue(description.contains("Error 1"))
        XCTAssertTrue(description.contains("field2"))
        XCTAssertTrue(description.contains("Error 2"))
    }
    
    func testDefaultErrorModelHasFieldErrors() {
        let errorWithFields = DefaultErrorModel(
            message: "Test error",
            fieldErrors: ["field1": ["Error 1"]]
        )
        
        let errorWithoutFields = DefaultErrorModel(message: "Test error")
        
        XCTAssertTrue(errorWithFields.hasFieldErrors)
        XCTAssertFalse(errorWithoutFields.hasFieldErrors)
    }
    
    func testDefaultErrorModelErrorsForField() {
        let errorModel = DefaultErrorModel(
            message: "Test error",
            fieldErrors: ["field1": ["Error 1", "Error 2"], "field2": ["Error 3"]]
        )
        
        XCTAssertEqual(errorModel.errors(forField: "field1"), ["Error 1", "Error 2"])
        XCTAssertEqual(errorModel.errors(forField: "field2"), ["Error 3"])
        XCTAssertNil(errorModel.errors(forField: "nonexistent"))
    }
    
    // MARK: - ErrorModelFactory Tests
    
    func testDefaultErrorModelFactoryCreation() {
        let factory = DefaultErrorModelFactory()
        let jsonData = """
        {
            "message": "Factory test error",
            "code": "FACTORY_ERROR"
        }
        """.data(using: .utf8)!
        
        let errorModel = factory.createErrorModel(from: jsonData, type: DefaultErrorModel.self)
        
        XCTAssertNotNil(errorModel)
        XCTAssertEqual(errorModel?.message, "Factory test error")
        XCTAssertEqual(errorModel?.code, "FACTORY_ERROR")
    }
    
    func testDefaultErrorModelFactoryExtraction() {
        let factory = DefaultErrorModelFactory()
        let jsonData = """
        {
            "message": "Extraction test error"
        }
        """.data(using: .utf8)!
        
        let errorModel = factory.extractErrorModel(from: jsonData)
        
        XCTAssertTrue(errorModel is DefaultErrorModel)
        XCTAssertEqual(errorModel.message, "Extraction test error")
    }
    
    func testDefaultErrorModelFactoryFallback() {
        let factory = DefaultErrorModelFactory()
        let invalidData = "Invalid JSON".data(using: .utf8)!
        
        let errorModel = factory.extractErrorModel(from: jsonData)
        
        XCTAssertTrue(errorModel is DefaultErrorModel)
        XCTAssertEqual(errorModel.message, "Unknown server error")
        XCTAssertEqual(errorModel.code, "UNKNOWN_ERROR")
    }
    
    // MARK: - NetworkError Tests
    
    func testNetworkErrorWithModelCases() {
        let errorModel = DefaultErrorModel(message: "Test error", code: "TEST_ERROR")
        
        let unauthError = NetworkError.unauthenticatedWithModel(error: errorModel)
        let tokenExpiredError = NetworkError.tokenExpiredWithModel(error: errorModel)
        let forbiddenError = NetworkError.forbiddenWithModel(error: errorModel)
        let appUpdateError = NetworkError.appUpdateRequiredWithModel(error: errorModel)
        
        XCTAssertEqual(unauthError.message, "Test error")
        XCTAssertEqual(tokenExpiredError.message, "Test error")
        XCTAssertEqual(forbiddenError.message, "Test error")
        XCTAssertEqual(appUpdateError.message, "Test error")
        
        XCTAssertEqual(unauthError.statusCode, 401)
        XCTAssertEqual(tokenExpiredError.statusCode, 401)
        XCTAssertEqual(forbiddenError.statusCode, 403)
        XCTAssertEqual(appUpdateError.statusCode, 426)
    }
    
    func testNetworkErrorModelEquality() {
        let errorModel1 = DefaultErrorModel(message: "Error 1")
        let errorModel2 = DefaultErrorModel(message: "Error 2")
        
        let error1 = NetworkError.unauthenticatedWithModel(error: errorModel1)
        let error2 = NetworkError.unauthenticatedWithModel(error: errorModel1)
        let error3 = NetworkError.unauthenticatedWithModel(error: errorModel2)
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    // MARK: - ErrorModelConfiguration Tests
    
    func testErrorModelConfigurationDefaults() {
        XCTAssertTrue(ErrorModelConfiguration.preferErrorModels)
        XCTAssertTrue(ErrorModelConfiguration.defaultErrorModelType is DefaultErrorModel.Type)
        XCTAssertNil(ErrorModelConfiguration.customFactory)
    }
    
    func testErrorModelConfiguration() {
        ErrorModelConfiguration.preferErrorModels = false
        
        XCTAssertFalse(ErrorModelConfiguration.preferErrorModels)
        
        // Reset to defaults
        ErrorModelConfiguration.resetToDefaults()
        
        XCTAssertTrue(ErrorModelConfiguration.preferErrorModels)
    }
}
