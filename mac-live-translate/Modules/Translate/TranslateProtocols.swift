//
//  TranslateProtocols.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  VIPER protocol contracts for the Translate module.
//

import Foundation

// MARK: - View -> Presenter

@MainActor
protocol TranslatePresenterInput: AnyObject {
    var state: TranslationState { get }
    func viewAppeared()
    func viewDisappeared()
    func toggleListening()
    func retryDownload()
    func deleteHistoryEntry(_ id: UUID)
    func clearHistory()
}

// MARK: - Presenter -> Interactor

@MainActor
protocol TranslateInteractorInput: AnyObject {
    func startListening()
    func stopListening()
    func checkTranslationAvailability()
    func resetTranslation()
}

// MARK: - Interactor -> Presenter

@MainActor
protocol TranslateInteractorOutput: AnyObject {
    func didUpdateSourceText(_ text: String)
    func didUpdateTranslation(_ text: String)
    func didFinishUtterance(chinese: String, english: String)
    func didChangeListeningState(_ isListening: Bool)
    func didChangeDownloadState(_ state: TranslationDownloadState)
    func didUpdateDownloadProgress(_ progress: DownloadProgress)
    func didEncounterError(_ message: String)
}
