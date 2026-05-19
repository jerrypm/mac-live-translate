//
//  MockTranslator.swift
//  mac-live-translateTests
//
//  In-memory Translating for tests. Returns canned translations + lets
//  tests drive download state changes.
//

import Foundation
@testable import mac_live_translate

@MainActor
final class MockTranslator: Translating {

    // MARK: - Configuration

    /// If set, `translate(_:)` returns this string. Defaults to "[en] <input>".
    var stubTranslation: String?

    /// Set to true to simulate translation failure (returns nil).
    var shouldFailTranslate = false

    // MARK: - Recorded calls

    private(set) var translateInputs: [String] = []
    private(set) var checkAvailabilityCallCount = 0

    // MARK: - Protocol surface

    var downloadState: TranslationDownloadState = .idle {
        didSet {
            if oldValue != downloadState {
                onDownloadStateChange?(downloadState)
            }
        }
    }

    var onDownloadStateChange: ((TranslationDownloadState) -> Void)?

    // MARK: - Translating

    func checkAvailability(source: String?, target: String?) async {
        checkAvailabilityCallCount += 1
        downloadState = .ready
    }

    func translate(_ text: String) async -> String? {
        translateInputs.append(text)
        if shouldFailTranslate { return nil }
        return stubTranslation ?? "[en] \(text)"
    }

    // MARK: - Test helpers

    func simulateDownloadState(_ state: TranslationDownloadState) {
        downloadState = state
    }
}
