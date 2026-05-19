//
//  TranslationService.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Orchestrates the on-device zh -> en translation lifecycle: preflight,
//  prepare, verify, and translate. Delegates the time-based progress
//  display to `DownloadProgressTicker` and the install verification to
//  `TranslationInstallVerifier`. All tuning lives in
//  `TranslationDownloadConfig` so behavior can be adjusted in one place.
//
//  Apple framework hazards this layer protects against:
//  - `prepareTranslation()` may hang; wrapped in `withTimeout`.
//  - `LanguageAvailability.status` may lag reality; verifier also probes
//    with a real test translation.
//  - The whole attach flow has a hard overall deadline so the UI cannot
//    sit at "downloading" forever.
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
        didSet { handleStateChange(from: oldValue, to: downloadState) }
    }
    private(set) var downloadProgress: DownloadProgress = .zero {
        didSet { notifyIfProgressChanged(from: oldValue) }
    }

    var onDownloadStateChange: ((TranslationDownloadState) -> Void)?
    var onDownloadProgressChange: ((DownloadProgress) -> Void)?

    // MARK: - Dependencies

    private let config: TranslationDownloadConfig
    private let progressTicker: DownloadProgressTicker

    // MARK: - Per-attempt state

    private var session: TranslationSession?
    private var currentSource: String
    private var currentTarget: String
    private var attachTask: Task<Void, Never>?

    // MARK: - Init

    init(
        config: TranslationDownloadConfig? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil
    ) {
        let resolvedConfig = config ?? TranslationDownloadConfig()
        self.config = resolvedConfig
        self.currentSource = sourceLanguage ?? Strings.Locale.sourceChinese
        self.currentTarget = targetLanguage ?? Strings.Locale.targetEnglish
        self.progressTicker = DownloadProgressTicker(config: resolvedConfig)

        progressTicker.onTick = { [weak self] progress in
            self?.downloadProgress = progress
        }
    }

    // MARK: - Translating

    func checkAvailability(source: String? = nil, target: String? = nil) async {
        guard downloadState == .idle else { return }

        currentSource = source ?? currentSource
        currentTarget = target ?? currentTarget

        downloadState = .checking

        switch await makeVerifier().snapshot() {
        case .installed:
            markReady()
        case .unsupported:
            markFailed(.languageUnsupported)
        case .proceedToDownload:
            downloadState = .downloading
        }
    }

    func reset() {
        cancelInflightWork()
        session = nil
        isReady = false
        downloadProgress = .zero
        downloadState = .idle
    }

    func translate(_ text: String) async -> String? {
        guard !text.isEmpty, let session else { return nil }
        do {
            return try await session.translate(text).targetText
        } catch {
            Logger.translation.error("translate failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - View bridge

    /// SwiftUI binds this to `.translationTask(configuration:)`. Replace it
    /// to make the framework re-vend a session (used by the retry flow).
    func makeConfiguration(
        source: String? = nil,
        target: String? = nil
    ) -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: source ?? currentSource),
            target: Locale.Language(identifier: target ?? currentTarget)
        )
    }

    /// Called by the view from inside `.translationTask` once the session is live.
    func attach(_ session: TranslationSession) async {
        self.session = session

        if downloadState == .ready, isReady { return }

        if downloadState != .downloading {
            downloadState = .downloading
        }

        attachTask?.cancel()
        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.runAttachOrchestration(using: session)
        }
        attachTask = task
        await task.value
    }

    func detach() {
        cancelInflightWork()
        session = nil
        isReady = false
        downloadState = .idle
    }

    // MARK: - Attach orchestration

    private func runAttachOrchestration(using session: TranslationSession) async {
        do {
            try await withTimeout(
                seconds: config.overallAttachBudgetSeconds,
                operationName: "translation download"
            ) { [weak self] in
                guard let self else { return }
                try await self.prepareAndVerify(using: session)
            }
        } catch is TimeoutError {
            markFailed(.downloadTimedOut)
        } catch is CancellationError {
            Logger.translation.info("Attach cancelled")
        } catch let failure as TranslationFailure {
            markFailed(failure)
        } catch {
            markFailed(.prepareFailed(error.localizedDescription))
        }
    }

    private func prepareAndVerify(using session: TranslationSession) async throws {
        await runPrepareTranslation(using: session)
        try await runVerification(using: session)
    }

    /// `prepareTranslation()` triggers Apple's download UI. If it hangs we
    /// don't fail outright - the model may still finish installing in the
    /// background, so we let the verification step decide.
    private func runPrepareTranslation(using session: TranslationSession) async {
        do {
            try await withTimeout(
                seconds: config.prepareTimeoutSeconds,
                operationName: "prepareTranslation"
            ) {
                try await session.prepareTranslation()
            }
            Logger.translation.info("prepareTranslation returned - verifying install")
        } catch {
            Logger.translation.info("prepareTranslation timed out - falling back to verifier")
        }
    }

    private func runVerification(using session: TranslationSession) async throws {
        switch try await makeVerifier().verify(using: session) {
        case .installed:
            markReady()
        case .unsupported:
            throw TranslationFailure.languageUnsupported
        case .timedOut:
            throw TranslationFailure.downloadTimedOut
        }
    }

    // MARK: - State helpers

    private func markReady() {
        isReady = true
        downloadState = .ready
    }

    private func markFailed(_ failure: TranslationFailure) {
        downloadState = .failed(failure.userMessage)
    }

    private func handleStateChange(
        from old: TranslationDownloadState,
        to new: TranslationDownloadState
    ) {
        guard old != new else { return }
        onDownloadStateChange?(new)
        applySideEffects(forEntering: new)
    }

    private func applySideEffects(forEntering state: TranslationDownloadState) {
        switch state {
        case .downloading:
            progressTicker.start()
        case .ready:
            progressTicker.stop()
            downloadProgress = DownloadProgress(
                elapsedSeconds: downloadProgress.elapsedSeconds,
                estimatedPercent: 100
            )
        case .failed, .idle:
            progressTicker.stop()
            downloadProgress = .zero
        case .checking:
            break
        }
    }

    private func notifyIfProgressChanged(from old: DownloadProgress) {
        guard old != downloadProgress else { return }
        onDownloadProgressChange?(downloadProgress)
    }

    private func cancelInflightWork() {
        attachTask?.cancel()
        attachTask = nil
        progressTicker.stop()
    }

    private func makeVerifier() -> TranslationInstallVerifier {
        TranslationInstallVerifier(
            sourceLanguage: currentSource,
            targetLanguage: currentTarget,
            config: config
        )
    }
}

// MARK: - Local failure type

private enum TranslationFailure: Error {
    case languageUnsupported
    case downloadTimedOut
    case prepareFailed(String)

    var userMessage: String {
        switch self {
        case .languageUnsupported:
            return Strings.Error.translationLanguagePairUnsupported
        case .downloadTimedOut:
            return Strings.Error.translationDownloadTimeout
        case .prepareFailed(let detail):
            return String(format: Strings.Error.translationPrepareFailedFormat, detail)
        }
    }
}
