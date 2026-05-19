//
//  TranslatePresenterTests.swift
//  mac-live-translateTests
//
//  Covers state transitions in the presenter, listen-gating behavior,
//  and the auto-start-on-ready transition.
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

    func test_viewAppeared_onlyTriggersAvailabilityCheck_doesNotStartListening() {
        presenter.viewAppeared()

        XCTAssertEqual(interactor.checkAvailabilityCallCount, 1)
        XCTAssertEqual(interactor.startCallCount, 0, "Must NOT start mic before model is ready")
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

    // MARK: - Auto-start on first ready transition

    func test_firstReadyTransition_autoStartsListening() {
        presenter.didChangeDownloadState(.ready)

        XCTAssertEqual(interactor.startCallCount, 1)
    }

    func test_secondReadyTransition_doesNotRestartListening() {
        presenter.didChangeDownloadState(.ready)
        presenter.didChangeListeningState(true)

        // Simulate user stopping the mic
        presenter.didChangeListeningState(false)

        // Some state churn that lands on .ready again
        presenter.didChangeDownloadState(.checking)
        presenter.didChangeDownloadState(.ready)

        XCTAssertEqual(interactor.startCallCount, 1, "Auto-start fires only once")
    }

    // MARK: - Toggle gating

    func test_toggleListening_isBlocked_whenNotReady() {
        presenter.didChangeDownloadState(.downloading)

        presenter.toggleListening()

        XCTAssertEqual(interactor.startCallCount, 0)
        XCTAssertEqual(interactor.stopCallCount, 0)
    }

    func test_toggleListening_whenReadyAndIdle_startsListening() {
        presenter.didChangeDownloadState(.ready)
        // Reset start count after auto-start fired.
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
        XCTAssertEqual(presenter.state.errorMessage, "boom")

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

    func test_didChangeDownloadState_failed_setsErrorMessage() {
        presenter.didChangeDownloadState(.failed("network"))

        XCTAssertEqual(presenter.state.downloadState, .failed("network"))
        XCTAssertEqual(presenter.state.errorMessage, "network")
    }

    func test_didChangeDownloadState_ready_clearsErrorMessage() {
        presenter.didChangeDownloadState(.failed("oops"))
        presenter.didChangeDownloadState(.ready)

        XCTAssertEqual(presenter.state.downloadState, .ready)
        XCTAssertNil(presenter.state.errorMessage)
    }
}

// MARK: - Spy

@MainActor
private final class SpyInteractor: TranslateInteractorInput {
    var startCallCount = 0
    var stopCallCount = 0
    var checkAvailabilityCallCount = 0

    func startListening() { startCallCount += 1 }
    func stopListening() { stopCallCount += 1 }
    func checkTranslationAvailability() { checkAvailabilityCallCount += 1 }
}
