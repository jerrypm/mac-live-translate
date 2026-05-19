//
//  AsyncTimeout.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Generic timeout wrapper for `async` work that may hang indefinitely
//  (Apple's Translation framework can lock up when downloads stall - we
//  need a hard deadline so the UI doesn't sit at 95% for 90 minutes).
//

import Foundation

struct TimeoutError: Error, LocalizedError {
    let operationName: String
    let seconds: Double

    var errorDescription: String? {
        "\(operationName) timed out after \(Int(seconds))s"
    }
}

/// Runs `operation` and races it against a sleep of `seconds`. The first to
/// finish wins; the other is cancelled. Throws `TimeoutError` if the timer
/// wins, or re-throws any error from `operation`.
func withTimeout<T: Sendable>(
    seconds: Double,
    operationName: String = "operation",
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(operationName: operationName, seconds: seconds)
        }

        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw TimeoutError(operationName: operationName, seconds: seconds)
        }
        return result
    }
}
