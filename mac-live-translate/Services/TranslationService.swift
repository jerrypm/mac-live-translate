//
//  TranslationService.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Wraps Apple Translation framework (macOS 15+) for on-device zh -> en.
//
//  Important: `prepareTranslation()` can resolve before the on-device model
//  is fully installed (e.g. when the user dismisses the OS sheet). The source
//  of truth is `LanguageAvailability().status`. After the framework signals
//  completion we poll availability until it reports `.installed`, otherwise
//  the overlay would close while files are still downloading.
//

import Foundation
import OSLog
import Translation

@MainActor
@Observable
final class TranslationService: Translating {

    // MARK: - State

    private(set) var isReady = false
    private(set) var downloadState: TranslationDownloadState = .idle {
        didSet {
            if oldValue != downloadState {
                onDownloadStateChange?(downloadState)
            }
        }
    }

    /// Fires whenever `downloadState` changes.
    var onDownloadStateChange: ((TranslationDownloadState) -> Void)?

    // MARK: - Tuning

    private let pollInterval: TimeInterval = 1.0
    private let pollMaxAttempts: Int = 120 // up to ~2 minutes

    // MARK: - Private

    private var session: TranslationSession?
    private var currentSource = Strings.Locale.sourceChinese
    private var currentTarget = Strings.Locale.targetEnglish

    // MARK: - Preflight

    func checkAvailability(
        source: String? = nil,
        target: String? = nil
    ) async {
        let src = source ?? Strings.Locale.sourceChinese
        let tgt = target ?? Strings.Locale.targetEnglish
        currentSource = src
        currentTarget = tgt

        downloadState = .checking

        let status = await currentInstallStatus()
        switch status {
        case .installed:
            isReady = true
            downloadState = .ready
        case .supported:
            // Not installed yet - .translationTask will trigger the OS sheet.
            downloadState = .downloading
        case .unsupported:
            downloadState = .failed(Strings.Error.translationUnavailable)
        @unknown default:
            downloadState = .failed(Strings.Error.translationUnavailable)
        }
    }

    // MARK: - Configuration

    func makeConfiguration(
        source: String? = nil,
        target: String? = nil
    ) -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: source ?? Strings.Locale.sourceChinese),
            target: Locale.Language(identifier: target ?? Strings.Locale.targetEnglish)
        )
    }

    /// Called by the view from inside `.translationTask`. Marks state `.ready`
    /// only after `LanguageAvailability` reports `.installed` - `prepareTranslation`
    /// alone is unreliable.
    func attach(_ session: TranslationSession) async {
        self.session = session

        if downloadState == .idle || downloadState == .checking {
            downloadState = .downloading
        }

        do {
            try await session.prepareTranslation()
            Logger.translation.info("prepareTranslation returned - verifying install")
        } catch {
            Logger.translation.error("prepareTranslation failed: \(error.localizedDescription)")
            downloadState = .failed(error.localizedDescription)
            return
        }

        await waitUntilInstalled()
    }

    func detach() {
        session = nil
        isReady = false
        downloadState = .idle
    }

    // MARK: - Translate

    func translate(_ text: String) async -> String? {
        guard !text.isEmpty, let session else { return nil }
        do {
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            Logger.translation.error("translate failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Install verification

    private func currentInstallStatus() async -> LanguageAvailability.Status {
        await LanguageAvailability().status(
            from: Locale.Language(identifier: currentSource),
            to: Locale.Language(identifier: currentTarget)
        )
    }

    private func waitUntilInstalled() async {
        for attempt in 0..<pollMaxAttempts {
            let status = await currentInstallStatus()
            if status == .installed {
                isReady = true
                downloadState = .ready
                Logger.translation.info("Translation model installed after \(attempt) poll attempts")
                return
            }
            if status == .unsupported {
                downloadState = .failed(Strings.Error.translationUnavailable)
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        downloadState = .failed(Strings.Error.translationUnavailable)
    }
}
