//
//  TranslationInstallVerifier.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Polls `LanguageAvailability` to confirm the on-device model is fully
//  installed. Apple's `prepareTranslation()` can resolve before the bytes
//  are really on disk, and `LanguageAvailability.status` can also lag
//  reality - so we periodically try a real translation as a robust
//  fallback signal that the model is functionally usable.
//

import Foundation
import OSLog
import Translation

@MainActor
final class TranslationInstallVerifier {

    /// Result of the polling loop.
    enum Verdict {
        case installed
        case unsupported
        case timedOut
    }

    /// Coarse-grained snapshot used by preflight (no polling).
    enum Snapshot {
        case installed
        case unsupported
        /// `.supported` from Apple, OR a timed-out/unknown status. The caller
        /// should proceed to the full download flow.
        case proceedToDownload
    }

    private let config: TranslationDownloadConfig
    private let sourceLanguage: String
    private let targetLanguage: String

    init(
        sourceLanguage: String,
        targetLanguage: String,
        config: TranslationDownloadConfig = TranslationDownloadConfig()
    ) {
        self.config = config
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    // MARK: - Preflight (one-shot)

    /// One status check with timeout. No polling, no test-translation probe.
    /// Used by `checkAvailability(...)` to decide whether the download flow
    /// needs to run.
    func snapshot() async -> Snapshot {
        guard let status = await currentInstallStatus() else {
            return .proceedToDownload
        }
        switch status {
        case .installed:    return .installed
        case .unsupported:  return .unsupported
        case .supported:    return .proceedToDownload
        @unknown default:   return .proceedToDownload
        }
    }

    // MARK: - Verification loop

    /// Polls until the model is confirmed installed, the framework reports
    /// unsupported, or the retry budget is exhausted. Throws `CancellationError`
    /// if the surrounding Task is cancelled.
    func verify(using session: TranslationSession) async throws -> Verdict {
        for attempt in 0..<config.pollMaxAttempts {
            try Task.checkCancellation()

            if let verdict = await pollOnce(attempt: attempt, session: session) {
                return verdict
            }

            try? await Task.sleep(nanoseconds: UInt64(config.pollInterval * 1_000_000_000))
        }

        return .timedOut
    }

    // MARK: - Single poll iteration

    private func pollOnce(
        attempt: Int,
        session: TranslationSession
    ) async -> Verdict? {
        switch await currentInstallStatus() {
        case .installed:
            Logger.translation.info("Model installed after \(attempt) poll attempts")
            return .installed
        case .unsupported:
            return .unsupported
        case .supported, .none:
            break
        @unknown default:
            break
        }

        if shouldProbeWithTestTranslation(at: attempt),
           await testTranslationSucceeds(using: session) {
            Logger.translation.info("Test translation succeeded - declaring ready")
            return .installed
        }
        return nil
    }

    // MARK: - Probes

    private func shouldProbeWithTestTranslation(at attempt: Int) -> Bool {
        attempt >= config.testProbeWarmupPolls
            && attempt % config.testProbeInterval == 0
    }

    private func testTranslationSucceeds(using session: TranslationSession) async -> Bool {
        guard let result = await tryTestTranslation(using: session) else { return false }
        return !result.isEmpty
    }

    private func tryTestTranslation(using session: TranslationSession) async -> String? {
        let probe = config.testTranslationProbe
        return await runBounded(name: "test translation") {
            try await session.translate(probe).targetText
        }
    }

    private func currentInstallStatus() async -> LanguageAvailability.Status? {
        await runBounded(name: "LanguageAvailability") { [sourceLanguage, targetLanguage] in
            await LanguageAvailability().status(
                from: Locale.Language(identifier: sourceLanguage),
                to: Locale.Language(identifier: targetLanguage)
            )
        }
    }

    // MARK: - Timeout wrapper

    private func runBounded<T: Sendable>(
        name: String,
        _ operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        do {
            return try await withTimeout(
                seconds: config.perCallTimeoutSeconds,
                operationName: name,
                operation: operation
            )
        } catch {
            Logger.translation.error("\(name) timed out / threw")
            return nil
        }
    }
}
