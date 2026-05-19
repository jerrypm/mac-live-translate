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

/// Snapshot of the in-progress download. Apple's framework does not expose
/// real byte progress, so `estimatedPercent` is time-based (capped at 95
/// until availability flips to `.installed`).
struct DownloadProgress: Equatable {
    var elapsedSeconds: Int
    var estimatedPercent: Int

    static let zero = DownloadProgress(elapsedSeconds: 0, estimatedPercent: 0)
}

@MainActor
protocol Translating: AnyObject {

    var downloadState: TranslationDownloadState { get }
    var downloadProgress: DownloadProgress { get }

    /// Fires whenever `downloadState` changes.
    var onDownloadStateChange: ((TranslationDownloadState) -> Void)? { get set }

    /// Fires when the time-based download progress ticks (~1 Hz).
    var onDownloadProgressChange: ((DownloadProgress) -> Void)? { get set }

    /// Check `LanguageAvailability` and update `downloadState` accordingly.
    /// Idempotent: skips work when the state is already past `.idle`.
    func checkAvailability(source: String?, target: String?) async

    /// Resets state back to `.idle` and cancels any in-flight install polling.
    /// Used by the retry flow so a fresh `checkAvailability` + `attach` can run.
    func reset()

    /// Translate `text` from configured source -> target. Returns `nil` if unavailable.
    func translate(_ text: String) async -> String?
}

extension Translating {
    /// Default-argument convenience wrapper for call sites.
    func checkAvailability() async {
        await checkAvailability(source: nil, target: nil)
    }
}
