//
//  TranslatePresenter.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Holds display state for TranslateView. Mediates between view and interactor.
//  Listening is gated on the translation model being fully installed.
//  Finalized utterances become history entries.
//

import Foundation

@Observable
@MainActor
final class TranslatePresenter: TranslatePresenterInput, TranslateInteractorOutput {

    // MARK: - State (observed by view)

    private(set) var state: TranslationState = .initial

    var canListen: Bool { state.downloadState == .ready }

    // MARK: - Dependencies

    private let interactor: TranslateInteractorInput

    // MARK: - Internal flags

    private var hasAutoStarted = false

    // MARK: - Init

    init(interactor: TranslateInteractorInput) {
        self.interactor = interactor
    }

    // MARK: - TranslatePresenterInput

    func viewAppeared() {
        state.errorMessage = nil
        interactor.checkTranslationAvailability()
    }

    func viewDisappeared() {
        interactor.stopListening()
    }

    func toggleListening() {
        guard canListen else { return }
        if state.isListening {
            interactor.stopListening()
        } else {
            interactor.startListening()
        }
    }

    func retryDownload() {
        state.errorMessage = nil
        interactor.resetTranslation()
        interactor.checkTranslationAvailability()
    }

    func deleteHistoryEntry(_ id: UUID) {
        state.history.removeAll { $0.id == id }
    }

    func clearHistory() {
        state.history.removeAll()
    }

    // MARK: - TranslateInteractorOutput

    func didUpdateSourceText(_ text: String) {
        state.sourceText = text
        state.errorMessage = nil
    }

    func didUpdateTranslation(_ text: String) {
        state.translatedText = text
    }

    func didFinishUtterance(chinese: String, english: String) {
        let entry = TranslationEntry(chineseText: chinese, englishText: english)
        state.history.insert(entry, at: 0)
        state.sourceText = ""
        state.translatedText = ""
    }

    func didChangeListeningState(_ isListening: Bool) {
        state.isListening = isListening
    }

    func didChangeDownloadState(_ downloadState: TranslationDownloadState) {
        state.downloadState = downloadState

        switch downloadState {
        case .failed(let message):
            state.errorMessage = message
        case .checking, .downloading, .ready:
            state.errorMessage = nil
            if case .ready = downloadState, !hasAutoStarted {
                hasAutoStarted = true
                interactor.startListening()
            }
        case .idle:
            break
        }
    }

    func didUpdateDownloadProgress(_ progress: DownloadProgress) {
        state.downloadProgress = progress
    }

    func didEncounterError(_ message: String) {
        state.errorMessage = message
        state.isListening = false
    }
}
