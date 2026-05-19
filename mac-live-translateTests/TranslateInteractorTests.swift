//
//  TranslateInteractorTests.swift
//  mac-live-translateTests
//
//  Covers the transcript pipeline: CJK filter, debounce, dedup, history
//  finalization, start/stop wiring, and download-state + progress forwarding.
//

import XCTest
@testable import mac_live_translate

@MainActor
final class TranslateInteractorTests: XCTestCase {

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

    func test_chineseFinalTranscript_emitsFinishUtterance_notUpdateTranslation() async {
        speech.emitTranscript("你好", isFinal: true)
        await waitForMainLoop()

        XCTAssertEqual(output.sourceTexts, ["你好"])
        XCTAssertEqual(translator.translateInputs, ["你好"])
        XCTAssertEqual(output.finishedUtterances.count, 1)
        XCTAssertEqual(output.finishedUtterances.first?.chinese, "你好")
        XCTAssertEqual(output.finishedUtterances.first?.english, "[en] 你好")
        XCTAssertTrue(output.translations.isEmpty, "Final translations go to didFinishUtterance, not didUpdateTranslation")
    }

    func test_chinesePartial_debounces_thenEmitsUpdateTranslation() async {
        speech.emitTranscript("你好", isFinal: false)
        await waitForMainLoop()
        XCTAssertEqual(output.sourceTexts, ["你好"])
        XCTAssertTrue(translator.translateInputs.isEmpty)

        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(translator.translateInputs, ["你好"])
        XCTAssertEqual(output.translations, ["[en] 你好"])
        XCTAssertTrue(output.finishedUtterances.isEmpty, "Partial translations must not finalize a history entry")
    }

    func test_duplicatePartial_isDeduped() async {
        speech.emitTranscript("你好", isFinal: false)
        try? await Task.sleep(nanoseconds: 500_000_000)

        speech.emitTranscript("你好", isFinal: false)
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(translator.translateInputs.count, 1, "Repeating the same partial must not re-translate")
    }

    func test_repeatedFinalUtterances_bothFinalize() async {
        speech.emitTranscript("你好", isFinal: true)
        await waitForMainLoop()

        speech.emitTranscript("你好", isFinal: true)
        await waitForMainLoop()

        XCTAssertEqual(output.finishedUtterances.count, 2,
                       "Two separate final utterances of the same text must both land in history")
    }

    // MARK: - Error + state forwarding

    func test_speechError_forwardedToOutput() async {
        speech.emitError("mic denied")
        await waitForMainLoop()

        XCTAssertEqual(output.errors, ["mic denied"])
    }

    func test_downloadStateChange_forwardedToOutput() async {
        translator.simulateDownloadState(.downloading)
        await waitForMainLoop()

        XCTAssertEqual(output.downloadStates, [.downloading])
    }

    func test_downloadProgressChange_forwardedToOutput() async {
        let progress = DownloadProgress(elapsedSeconds: 10, estimatedPercent: 25)
        translator.simulateDownloadProgress(progress)
        await waitForMainLoop()

        XCTAssertEqual(output.downloadProgress, [progress])
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
    struct FinishedUtterance: Equatable {
        let chinese: String
        let english: String
    }

    var sourceTexts: [String] = []
    var translations: [String] = []
    var finishedUtterances: [FinishedUtterance] = []
    var listeningStates: [Bool] = []
    var downloadStates: [TranslationDownloadState] = []
    var downloadProgress: [DownloadProgress] = []
    var errors: [String] = []

    func didUpdateSourceText(_ text: String)                      { sourceTexts.append(text) }
    func didUpdateTranslation(_ text: String)                     { translations.append(text) }
    func didFinishUtterance(chinese: String, english: String)     { finishedUtterances.append(.init(chinese: chinese, english: english)) }
    func didChangeListeningState(_ isListening: Bool)             { listeningStates.append(isListening) }
    func didChangeDownloadState(_ s: TranslationDownloadState)    { downloadStates.append(s) }
    func didUpdateDownloadProgress(_ p: DownloadProgress)         { downloadProgress.append(p) }
    func didEncounterError(_ message: String)                     { errors.append(message) }
}
