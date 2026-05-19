//
//  TranslateInteractorTests.swift
//  mac-live-translateTests
//
//  Covers the transcript pipeline: CJK filter, debounce, dedup,
//  start/stop wiring, and download-state forwarding.
//

import XCTest
@testable import mac_live_translate

@MainActor
final class TranslateInteractorTests: XCTestCase {

    // MARK: - System under test

    private var speech: MockSpeechRecognizer!
    private var translator: MockTranslator!
    private var interactor: TranslateInteractor!
    private var output: SpyOutput!

    override func setUp() {
        super.setUp()
        speech = MockSpeechRecognizer()
        translator = MockTranslator()
        interactor = TranslateInteractor(
            speechService: speech,
            translationService: translator
        )
        output = SpyOutput()
        interactor.output = output
    }

    override func tearDown() {
        interactor = nil
        speech = nil
        translator = nil
        output = nil
        super.tearDown()
    }

    // MARK: - Listening control

    func test_startListening_callsSpeechService_andEmitsListeningTrue() {
        interactor.startListening()

        XCTAssertEqual(speech.requestAuthCallCount, 1)
        XCTAssertEqual(speech.startCallCount, 1)
        XCTAssertEqual(output.listeningStates, [true])
    }

    func test_stopListening_callsSpeechService_andEmitsListeningFalse() {
        interactor.stopListening()

        XCTAssertEqual(speech.stopCallCount, 1)
        XCTAssertEqual(output.listeningStates, [false])
    }

    // MARK: - Transcript filter

    func test_nonChineseTranscript_isIgnored() async {
        speech.emitTranscript("Hello world", isFinal: false)

        await waitForMainLoop()

        XCTAssertTrue(output.sourceTexts.isEmpty)
        XCTAssertTrue(translator.translateInputs.isEmpty)
    }

    func test_chineseFinalTranscript_translatesImmediately() async {
        speech.emitTranscript("你好", isFinal: true)

        await waitForMainLoop()

        XCTAssertEqual(output.sourceTexts, ["你好"])
        XCTAssertEqual(translator.translateInputs, ["你好"])
        XCTAssertEqual(output.translations, ["[en] 你好"])
    }

    func test_chinesePartial_debounces_thenTranslates() async {
        speech.emitTranscript("你好", isFinal: false)
        await waitForMainLoop()
        XCTAssertEqual(output.sourceTexts, ["你好"])
        // Translator not invoked immediately on partial.
        XCTAssertTrue(translator.translateInputs.isEmpty)

        // Debounce is 0.3s - wait well past it.
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(translator.translateInputs, ["你好"])
    }

    func test_duplicateText_skipsRedundantTranslate() async {
        speech.emitTranscript("你好", isFinal: true)
        await waitForMainLoop()

        speech.emitTranscript("你好", isFinal: true)
        await waitForMainLoop()

        XCTAssertEqual(translator.translateInputs.count, 1)
    }

    // MARK: - Error forwarding

    func test_speechError_forwardedToOutput() async {
        speech.emitError("mic denied")
        await waitForMainLoop()

        XCTAssertEqual(output.errors, ["mic denied"])
    }

    // MARK: - Download state forwarding

    func test_downloadStateChange_forwardedToOutput() async {
        translator.simulateDownloadState(.downloading)
        await waitForMainLoop()

        XCTAssertEqual(output.downloadStates, [.downloading])
    }

    func test_checkTranslationAvailability_callsTranslator() async {
        interactor.checkTranslationAvailability()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(translator.checkAvailabilityCallCount, 1)
    }

    // MARK: - Helpers

    private func waitForMainLoop() async {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
}

// MARK: - Spy

@MainActor
private final class SpyOutput: TranslateInteractorOutput {
    var sourceTexts: [String] = []
    var translations: [String] = []
    var listeningStates: [Bool] = []
    var downloadStates: [TranslationDownloadState] = []
    var errors: [String] = []

    func didUpdateSourceText(_ text: String)               { sourceTexts.append(text) }
    func didUpdateTranslation(_ text: String)              { translations.append(text) }
    func didChangeListeningState(_ isListening: Bool)      { listeningStates.append(isListening) }
    func didChangeDownloadState(_ s: TranslationDownloadState) { downloadStates.append(s) }
    func didEncounterError(_ message: String)              { errors.append(message) }
}
