//
//  TranslateInteractor.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Owns the speech + translation services. Filters out non-Chinese noise,
//  debounces partial transcripts, and routes final utterances to history.
//

import Foundation
import OSLog

@MainActor
final class TranslateInteractor: TranslateInteractorInput {

    weak var output: TranslateInteractorOutput?

    // MARK: - Dependencies

    private let speechService: SpeechRecognizing
    private let translationService: Translating

    // MARK: - Debounce + dedup

    private var debounceTask: Task<Void, Never>?
    private var lastTranslatedText: String = ""

    // MARK: - Init

    init(
        speechService: SpeechRecognizing,
        translationService: Translating
    ) {
        self.speechService = speechService
        self.translationService = translationService
        wireCallbacks()
    }

    // MARK: - TranslateInteractorInput

    func startListening() {
        speechService.requestAuthorizationAndStart()
        output?.didChangeListeningState(true)
    }

    func stopListening() {
        speechService.stop()
        debounceTask?.cancel()
        output?.didChangeListeningState(false)
    }

    func checkTranslationAvailability() {
        Task { [weak self] in
            await self?.translationService.checkAvailability()
        }
    }

    func resetTranslation() {
        translationService.reset()
    }

    // MARK: - Wiring

    private func wireCallbacks() {
        speechService.onTranscript = { [weak self] text, isFinal in
            Task { @MainActor in
                self?.handleTranscript(text, isFinal: isFinal)
            }
        }

        speechService.onError = { [weak self] message in
            Task { @MainActor in
                self?.output?.didEncounterError(message)
            }
        }

        translationService.onDownloadStateChange = { [weak self] state in
            Task { @MainActor in
                self?.output?.didChangeDownloadState(state)
            }
        }

        translationService.onDownloadProgressChange = { [weak self] progress in
            Task { @MainActor in
                self?.output?.didUpdateDownloadProgress(progress)
            }
        }
    }

    // MARK: - Transcript pipeline

    private func handleTranscript(_ text: String, isFinal: Bool) {
        guard text.containsChinese else {
            Logger.translation.debug("Ignored non-Chinese transcript")
            return
        }

        output?.didUpdateSourceText(text)

        if isFinal {
            debounceTask?.cancel()
            translateNow(text, isFinal: true)
        } else {
            scheduleDebouncedTranslate(text)
        }
    }

    private func scheduleDebouncedTranslate(_ text: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(Metrics.Duration.translateDebounce * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            self?.translateNow(text, isFinal: false)
        }
    }

    private func translateNow(_ text: String, isFinal: Bool) {
        // Dedup applies to partials so we don't re-translate the same prefix
        // back-to-back; finals always emit so two identical utterances both
        // land in history.
        if !isFinal, text == lastTranslatedText { return }
        lastTranslatedText = text

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let translated = await self.translationService.translate(text) else { return }

            if isFinal {
                self.output?.didFinishUtterance(chinese: text, english: translated)
                self.lastTranslatedText = ""
            } else {
                self.output?.didUpdateTranslation(translated)
            }
        }
    }
}
