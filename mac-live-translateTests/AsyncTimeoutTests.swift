//
//  AsyncTimeoutTests.swift
//  mac-live-translateTests
//
//  Verifies the timeout helper that protects the translation flow from
//  hanging Apple framework calls.
//

import XCTest
@testable import mac_live_translate

final class AsyncTimeoutTests: XCTestCase {

    func test_fastOperation_completesNormally() async throws {
        let result = try await withTimeout(seconds: 1.0) {
            42
        }
        XCTAssertEqual(result, 42)
    }

    func test_slowOperation_throwsTimeoutError() async {
        do {
            _ = try await withTimeout(seconds: 0.2, operationName: "slow") {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return "should not reach"
            }
            XCTFail("Expected TimeoutError")
        } catch let timeout as TimeoutError {
            XCTAssertEqual(timeout.operationName, "slow")
            XCTAssertEqual(timeout.seconds, 0.2, accuracy: 0.01)
        } catch {
            XCTFail("Expected TimeoutError, got \(error)")
        }
    }

    func test_operationThrowingError_propagatesError() async {
        struct DummyError: Error, Equatable {}

        do {
            _ = try await withTimeout(seconds: 1.0) {
                throw DummyError()
            }
            XCTFail("Expected DummyError")
        } catch is DummyError {
            // expected
        } catch {
            XCTFail("Expected DummyError, got \(error)")
        }
    }
}
