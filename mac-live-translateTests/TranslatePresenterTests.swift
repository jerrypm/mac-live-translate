//
//  TranslatePresenterTests.swift
//  mac-live-translateTests
//
//  Covers state transitions, listen-gating, auto-start, progress mirroring,
//  error clearing on recovery, and history append/delete/clear.
//

import XCTest
@testable import mac_live_translate

@MainActor
final class TranslatePresenterTests: XCTestCase {

    private var interactor: SpyInteractor!
    private var presenter: TranslatePresenter!

    override func setUp() {
        super.setUp()
        interactor = SpyInteractor()
        presenter = TranslatePresenter(interactor: interactor)
    }

    override func tearDown() {
        presenter = nil
        interactor = nil
        super.tearDown()
    }

    // MARK: - Lifecycle

    func test_viewAppeared_clearsError_andTriggersAvailabilityCheck() {
        presenter.didEncounterError("stale")
        presenter.viewAppeared()

        XCTAssertNil(presenter.state.errorMessage)
        XCTAssertEqual(interactor.checkAvailabilityCallCount, 1)
        XCTAssertEqual(interactor.startCallCount, 0)
    }

    func test_viewDisappeared_stopsListening() {
        presenter.viewDisappeared()
        XCTAssertEqual(interactor.stopCallCount, 1)
    }

    // MARK: - canListen gate

    func test_canListen_isFalse_whenNotReady() {
        XCTAssertFalse(presenter.canListen)
        presenter.didChangeDownloadState(.checking)
        XCTAssertFalse(presenter.canListen)
        presenter.didChangeDownloadState(.downloading)
        XCTAssertFalse(presenter.canListen)
    }

    func test_canListen_isTrue_whenReady() {
        presenter.didChangeDownloadState(.ready)
        XCTAssertTrue(presenter.canListen)
    }

    // MARK: - Auto-start on first ready

    func test_firstReadyTransition_autoStartsListening() {
        presenter.didChangeDownloadState(.ready)
        XCTAssertEqual(interactor.startCallCount, 1)
    }

    func test_secondReadyTransition_doesNotRestart() {
        presenter.didChangeDownloadState(.ready)
        presenter.didChangeListeningState(true)
        presenter.didChangeListeningState(false)
        presenter.didChangeDownloadState(.checking)
        presenter.didChangeDownloadState(.ready)

        XCTAssertEqual(interactor.startCallCount, 1)
    }

    // MARK: - Toggle gating

    func test_toggleListening_blocked_whenNotReady() {
        presenter.didChangeDownloadState(.downloading)
        presenter.toggleListening()
        XCTAssertEqual(interactor.startCallCount, 0)
        XCTAssertEqual(interactor.stopCallCount, 0)
    }

    func test_toggleListening_whenReadyAndIdle_starts() {
        presenter.didChangeDownloadState(.ready)
        interactor.startCallCount = 0
        presenter.didChangeListeningState(false)

        presenter.toggleListening()
        XCTAssertEqual(interactor.startCallCount, 1)
    }

    func test_toggleListening_whenReadyAndListening_stops() {
        presenter.didChangeDownloadState(.ready)
        presenter.didChangeListeningState(true)

        presenter.toggleListening()
        XCTAssertEqual(interactor.stopCallCount, 1)
    }

    // MARK: - State updates

    func test_didUpdateSourceText_updatesState_andClearsError() {
        presenter.didEncounterError("boom")
        presenter.didUpdateSourceText("你好")

        XCTAssertEqual(presenter.state.sourceText, "你好")
        XCTAssertNil(presenter.state.errorMessage)
    }

    func test_didUpdateTranslation_updatesState() {
        presenter.didUpdateTranslation("Hello")
        XCTAssertEqual(presenter.state.translatedText, "Hello")
    }

    func test_didEncounterError_setsErrorAndStopsListening() {
        presenter.didChangeListeningState(true)
        presenter.didEncounterError("mic denied")

        XCTAssertEqual(presenter.state.errorMessage, "mic denied")
        XCTAssertFalse(presenter.state.isListening)
    }

    // MARK: - Download state recovery

    func test_didChangeDownloadState_failed_setsErrorMessage() {
        presenter.didChangeDownloadState(.failed("network"))
        XCTAssertEqual(presenter.state.errorMessage, "network")
    }

    func test_didChangeDownloadState_checking_clearsStaleDownloadError() {
        presenter.didChangeDownloadState(.failed("oops"))
        presenter.didChangeDownloadState(.checking)
        XCTAssertNil(presenter.state.errorMessage)
    }

    func test_didChangeDownloadState_downloading_clearsStaleDownloadError() {
        presenter.didChangeDownloadState(.failed("oops"))
        presenter.didChangeDownloadState(.downloading)
        XCTAssertNil(presenter.state.errorMessage)
    }

    func test_didChangeDownloadState_ready_clearsErrorMessage() {
        presenter.didChangeDownloadState(.failed("oops"))
        presenter.didChangeDownloadState(.ready)
        XCTAssertNil(presenter.state.errorMessage)
    }

    // MARK: - Add-to-history button (keeps current panes intact)

    func test_addCurrentToHistory_withPendingUtterance_insertsEntry_andKeepsPanes() {
        presenter.didUpdateSourceText("你好")
        presenter.didUpdateTranslation("Hello")

        presenter.addCurrentToHistory()

        XCTAssertEqual(presenter.state.history.count, 1)
        XCTAssertEqual(presenter.state.history.first?.chineseText, "你好")
        XCTAssertEqual(presenter.state.history.first?.englishText, "Hello")
        XCTAssertEqual(presenter.state.sourceText, "你好",
                       "Add must NOT clear the source pane")
        XCTAssertEqual(presenter.state.translatedText, "Hello",
                       "Add must NOT clear the translation pane")
    }

    func test_addCurrentToHistory_withEmptyPanes_isNoop() {
        presenter.addCurrentToHistory()
        XCTAssertTrue(presenter.state.history.isEmpty)
    }

    func test_addCurrentToHistory_withSourceOnly_isNoop() {
        presenter.didUpdateSourceText("你好")

        presenter.addCurrentToHistory()

        XCTAssertTrue(presenter.state.history.isEmpty,
                      "Don't record a half-finished entry with no translation")
    }

    func test_canAddCurrentToHistory_reflectsPaneContents() {
        XCTAssertFalse(presenter.canAddCurrentToHistory)

        presenter.didUpdateSourceText("你好")
        XCTAssertFalse(presenter.canAddCurrentToHistory)

        presenter.didUpdateTranslation("Hello")
        XCTAssertTrue(presenter.canAddCurrentToHistory)
    }

    // MARK: - Finalize-on-pause (regression for: pausing mid-utterance lost text)

    func test_toggleListening_whenListeningWithPendingUtterance_promotesToHistory() {
        presenter.didChangeDownloadState(.ready)
        presenter.didChangeListeningState(true)
        presenter.didUpdateSourceText("谢谢")
        presenter.didUpdateTranslation("Thank you")

        presenter.toggleListening()

        XCTAssertEqual(presenter.state.history.count, 1, "Pending utterance must be promoted on pause")
        XCTAssertEqual(presenter.state.history.first?.chineseText, "谢谢")
        XCTAssertEqual(presenter.state.history.first?.englishText, "Thank you")
        XCTAssertEqual(presenter.state.sourceText, "")
        XCTAssertEqual(presenter.state.translatedText, "")
        XCTAssertEqual(interactor.stopCallCount, 1)
    }

    func test_toggleListening_whenListeningWithNoPendingUtterance_doesNotInsertEmptyEntry() {
        presenter.didChangeDownloadState(.ready)
        presenter.didChangeListeningState(true)

        presenter.toggleListening()

        XCTAssertTrue(presenter.state.history.isEmpty)
        XCTAssertEqual(interactor.stopCallCount, 1)
    }

    func test_toggleListening_whenSourceWithoutTranslation_doesNotInsertPartialEntry() {
        presenter.didChangeDownloadState(.ready)
        presenter.didChangeListeningState(true)
        presenter.didUpdateSourceText("谢谢")
        // No translation yet

        presenter.toggleListening()

        XCTAssertTrue(presenter.state.history.isEmpty,
                      "Don't record a half-finished utterance with no translation")
    }

    func test_viewDisappeared_withPendingUtterance_promotesToHistory() {
        presenter.didChangeDownloadState(.ready)
        presenter.didChangeListeningState(true)
        presenter.didUpdateSourceText("你好")
        presenter.didUpdateTranslation("Hello")

        presenter.viewDisappeared()

        XCTAssertEqual(presenter.state.history.count, 1)
        XCTAssertEqual(interactor.stopCallCount, 1)
    }

    // MARK: - Retry flow (regression for Bug: retry button did nothing)

    func test_retryDownload_clearsError_resetsService_andRechecks() {
        presenter.didChangeDownloadState(.failed("download failed"))
        XCTAssertEqual(presenter.state.errorMessage, "download failed")

        presenter.retryDownload()

        XCTAssertNil(presenter.state.errorMessage, "Retry must clear stale error")
        XCTAssertEqual(interactor.resetTranslationCallCount, 1, "Retry must reset the service so checkAvailability re-opens")
        XCTAssertEqual(interactor.checkAvailabilityCallCount, 1, "Retry must trigger a fresh availability check")
    }

    // MARK: - Progress

    func test_didUpdateDownloadProgress_mirrorsToState() {
        let p = DownloadProgress(elapsedSeconds: 12, estimatedPercent: 30)
        presenter.didUpdateDownloadProgress(p)
        XCTAssertEqual(presenter.state.downloadProgress, p)
    }

    // MARK: - History

    func test_didFinishUtterance_prependsHistoryEntry_andClearsCurrentPanes() {
        presenter.didUpdateSourceText("你好")
        presenter.didUpdateTranslation("Hello (partial)")

        presenter.didFinishUtterance(chinese: "你好", english: "Hello")

        XCTAssertEqual(presenter.state.history.count, 1)
        XCTAssertEqual(presenter.state.history.first?.chineseText, "你好")
        XCTAssertEqual(presenter.state.history.first?.englishText, "Hello")
        XCTAssertEqual(presenter.state.sourceText, "")
        XCTAssertEqual(presenter.state.translatedText, "")
    }

    func test_didFinishUtterance_putsNewestFirst() {
        presenter.didFinishUtterance(chinese: "第一", english: "First")
        presenter.didFinishUtterance(chinese: "第二", english: "Second")

        XCTAssertEqual(presenter.state.history.count, 2)
        XCTAssertEqual(presenter.state.history[0].englishText, "Second")
        XCTAssertEqual(presenter.state.history[1].englishText, "First")
    }

    func test_deleteHistoryEntry_removesById() {
        presenter.didFinishUtterance(chinese: "一", english: "One")
        presenter.didFinishUtterance(chinese: "二", english: "Two")
        let toDelete = presenter.state.history[0].id

        presenter.deleteHistoryEntry(toDelete)

        XCTAssertEqual(presenter.state.history.count, 1)
        XCTAssertEqual(presenter.state.history.first?.englishText, "One")
    }

    func test_deleteHistoryEntry_unknownId_isNoop() {
        presenter.didFinishUtterance(chinese: "一", english: "One")
        presenter.deleteHistoryEntry(UUID())
        XCTAssertEqual(presenter.state.history.count, 1)
    }

    func test_clearHistory_emptiesList() {
        presenter.didFinishUtterance(chinese: "一", english: "One")
        presenter.didFinishUtterance(chinese: "二", english: "Two")

        presenter.clearHistory()

        XCTAssertTrue(presenter.state.history.isEmpty)
    }
}

// MARK: - Spy

@MainActor
private final class SpyInteractor: TranslateInteractorInput {
    var startCallCount = 0
    var stopCallCount = 0
    var checkAvailabilityCallCount = 0
    var resetTranslationCallCount = 0

    func startListening() { startCallCount += 1 }
    func stopListening() { stopCallCount += 1 }
    func checkTranslationAvailability() { checkAvailabilityCallCount += 1 }
    func resetTranslation() { resetTranslationCallCount += 1 }
}
