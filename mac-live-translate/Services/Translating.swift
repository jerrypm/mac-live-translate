//
//  Translating.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Abstraction over Apple Translation framework so the interactor can be
//  unit-tested with a mock translator that returns canned responses.
//

import Foundation

/// Lifecycle of the on-device translation model download.
enum TranslationDownloadState: Equatable {
    case idle
    case checking
    case downloading
    case ready
    case failed(String)
}

@MainActor
protocol Translating: AnyObject {

    var downloadState: TranslationDownloadState { get }

    /// Fires whenever `downloadState` changes.
    var onDownloadStateChange: ((TranslationDownloadState) -> Void)? { get set }

    /// Check `LanguageAvailability` and update `downloadState` accordingly.
    func checkAvailability(source: String?, target: String?) async

    /// Translate `text` from configured source -> target. Returns `nil` if unavailable.
    func translate(_ text: String) async -> String?
}

extension Translating {
    /// Default-argument convenience wrapper for call sites.
    func checkAvailability() async {
        await checkAvailability(source: nil, target: nil)
    }
}
