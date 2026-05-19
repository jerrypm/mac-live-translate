//
//  MockTranslator.swift
//  mac-live-translateTests
//
//  In-memory Translating for tests. Returns canned translations + lets
//  tests drive download state and progress changes.
//

import Foundation
@testable import mac_live_translate

@MainActor
final class MockTranslator: Translating {

    // MARK: - Configuration

    var stubTranslation: String?
    var shouldFailTranslate = false

    // MARK: - Recorded calls

    private(set) var translateInputs: [String] = []
    private(set) var checkAvailabilityCallCount = 0
    private(set) var resetCallCount = 0

    // MARK: - Protocol surface

    var downloadState: TranslationDownloadState = .idle {
        didSet {
            if oldValue != downloadState {
                onDownloadStateChange?(downloadState)
            }
        }
    }

    var downloadProgress: DownloadProgress = .zero {
        didSet {
            if oldValue != downloadProgress {
                onDownloadProgressChange?(downloadProgress)
            }
        }
    }

    var onDownloadStateChange: ((TranslationDownloadState) -> Void)?
    var onDownloadProgressChange: ((DownloadProgress) -> Void)?

    // MARK: - Translating

    func checkAvailability(source: String?, target: String?) async {
        checkAvailabilityCallCount += 1
        if downloadState == .idle {
            downloadState = .ready
        }
    }

    func reset() {
        resetCallCount += 1
        downloadState = .idle
        downloadProgress = .zero
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

    func simulateDownloadProgress(_ progress: DownloadProgress) {
        downloadProgress = progress
    }
}
