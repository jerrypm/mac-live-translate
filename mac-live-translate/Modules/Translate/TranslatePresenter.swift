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
        finalizePendingUtterance()
        interactor.stopListening()
    }

    func toggleListening() {
        guard canListen else { return }
        if state.isListening {
            // Pausing mid-utterance would otherwise lose the current text -
            // promote it to history before tearing down the speech session.
            finalizePendingUtterance()
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

    /// Snapshots the current utterance into history but keeps the live panes
    /// populated so the user can keep speaking. Unlike pausing the mic, this
    /// does NOT clear the source/translation text.
    func addCurrentToHistory() {
        let chinese = state.sourceText
        let english = state.translatedText
        guard !chinese.isEmpty, !english.isEmpty else { return }
        let entry = TranslationEntry(chineseText: chinese, englishText: english)
        state.history.insert(entry, at: 0)
    }

    /// True when there is a fully-translated utterance available to snapshot.
    var canAddCurrentToHistory: Bool {
        !state.sourceText.isEmpty && !state.translatedText.isEmpty
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

    // MARK: - Helpers

    /// Move any in-progress utterance to history before pausing/stopping.
    /// The Apple speech recognizer only emits a final result on natural
    /// silence; if the user toggles the mic off mid-sentence we'd lose the
    /// text without this. Skipped if either pane is empty.
    private func finalizePendingUtterance() {
        let chinese = state.sourceText
        let english = state.translatedText
        guard !chinese.isEmpty, !english.isEmpty else { return }
        didFinishUtterance(chinese: chinese, english: english)
    }
}
