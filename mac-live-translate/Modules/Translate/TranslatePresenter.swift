//
//  TranslatePresenter.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Holds display state for TranslateView. Mediates between view and interactor.
//  Listening is gated on the translation model being fully installed - the mic
//  must not start until `downloadState == .ready`.
//

import Foundation

@Observable
@MainActor
final class TranslatePresenter: TranslatePresenterInput, TranslateInteractorOutput {

    // MARK: - State (observed by view)

    private(set) var state: TranslationState = .initial

    /// True only when the translation model is fully installed and listening is allowed.
    var canListen: Bool { state.downloadState == .ready }

    // MARK: - Dependencies

    private let interactor: TranslateInteractorInput

    // MARK: - Internal flags

    /// Auto-start listening once on the first ready transition. After that, respect user's toggle.
    private var hasAutoStarted = false

    // MARK: - Init

    init(interactor: TranslateInteractorInput) {
        self.interactor = interactor
    }

    // MARK: - TranslatePresenterInput

    func viewAppeared() {
        interactor.checkTranslationAvailability()
        // Listening intentionally NOT started here - gated on `.ready`.
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

    // MARK: - TranslateInteractorOutput

    func didUpdateSourceText(_ text: String) {
        state.sourceText = text
        state.errorMessage = nil
    }

    func didUpdateTranslation(_ text: String) {
        state.translatedText = text
    }

    func didChangeListeningState(_ isListening: Bool) {
        state.isListening = isListening
    }

    func didChangeDownloadState(_ downloadState: TranslationDownloadState) {
        state.downloadState = downloadState

        switch downloadState {
        case .failed(let message):
            state.errorMessage = message
        case .ready:
            state.errorMessage = nil
            if !hasAutoStarted {
                hasAutoStarted = true
                interactor.startListening()
            }
        case .idle, .checking, .downloading:
            break
        }
    }

    func didEncounterError(_ message: String) {
        state.errorMessage = message
        state.isListening = false
    }
}
