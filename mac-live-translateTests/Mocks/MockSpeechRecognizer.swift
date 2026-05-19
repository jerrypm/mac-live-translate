//
//  MockSpeechRecognizer.swift
//  mac-live-translateTests
//
//  In-memory SpeechRecognizing for tests. Tracks calls + lets tests
//  inject transcripts and errors synchronously.
//

import Foundation
@testable import mac_live_translate

@MainActor
final class MockSpeechRecognizer: SpeechRecognizing {

    // MARK: - Recorded calls

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var requestAuthCallCount = 0

    // MARK: - Protocol surface

    var onTranscript: ((String, _ isFinal: Bool) -> Void)?
    var onError: ((String) -> Void)?
    var isRunning = false

    // MARK: - SpeechRecognizing

    func requestAuthorizationAndStart() {
        requestAuthCallCount += 1
        start()
    }

    func start() {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    // MARK: - Test helpers

    func emitTranscript(_ text: String, isFinal: Bool) {
        onTranscript?(text, isFinal)
    }

    func emitError(_ message: String) {
        onError?(message)
    }
}
