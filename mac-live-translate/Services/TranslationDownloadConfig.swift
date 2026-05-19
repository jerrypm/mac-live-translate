//
//  TranslationDownloadConfig.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  All tuning knobs for the translation-model download flow.
//  Defaults are based on real-world observation; tests can inject a faster
//  variant to keep test runs quick.
//
//  Marked `Sendable` and constructed without MainActor isolation so the
//  `init(config:)` of MainActor classes can take it as a nonisolated default.
//

import Foundation

struct TranslationDownloadConfig: Sendable {

    /// How long we *expect* a typical download to take. Used only by the
    /// time-based UI progress estimate.
    var expectedDownloadSeconds: Double = 60

    /// Interval between `LanguageAvailability.status` polls during verification.
    var pollInterval: TimeInterval = 1.0

    /// Maximum number of polls before declaring the download timed out.
    var pollMaxAttempts: Int = 240

    /// Polls before we start probing with a test translation as a robust fallback.
    var testProbeWarmupPolls: Int = 5

    /// How often to try a test translation as a fallback (`attempt % this == 0`).
    var testProbeInterval: Int = 5

    /// Per-call timeout for any `LanguageAvailability` or test-translation call.
    var perCallTimeoutSeconds: Double = 10

    /// Per-call timeout for `prepareTranslation`.
    var prepareTimeoutSeconds: Double = 180

    /// Hard ceiling for the entire attach flow.
    var overallAttachBudgetSeconds: Double = 300

    /// Tick rate for the time-based UI progress ticker.
    var progressTickerInterval: TimeInterval = 1.0

    /// Cap the time-based estimate at this percent until install is confirmed.
    var maxEstimatedPercent: Int = 95

    /// Sample text used for the install-verification translation probe.
    var testTranslationProbe: String = "你好"

    /// Explicit nonisolated init so callers in `MainActor`-isolated default
    /// arguments don't trip on the implicit synthesized init.
    nonisolated init() {}
}
