//
//  TranslationState.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Plain value type holding the current live-translate UI state.
//

import Foundation

struct TranslationState: Equatable {
    var sourceText: String
    var translatedText: String
    var isListening: Bool
    var downloadState: TranslationDownloadState
    var downloadProgress: DownloadProgress
    var history: [TranslationEntry]
    var errorMessage: String?

    static let initial = TranslationState(
        sourceText: "",
        translatedText: "",
        isListening: false,
        downloadState: .idle,
        downloadProgress: .zero,
        history: [],
        errorMessage: nil
    )
}
