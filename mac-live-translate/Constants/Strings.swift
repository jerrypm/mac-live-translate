//
//  Strings.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Centralized string constants - locale codes, UI labels, keys.
//

import Foundation

enum Strings {

    enum Locale {
        static let sourceChinese = "zh-CN"
        static let targetEnglish = "en-US"
        static let targetIndonesian = "id-ID"
    }

    enum UI {
        static let sourceLanguageLabel = "Chinese (Simplified)"
        static let targetLanguageLabel = "English"
        static let sourcePlaceholder = "Listening..."
        static let targetPlaceholder = "Translation"
        static let windowTitle = "Live Translate"
        static let micIconListening = "mic.fill"
        static let micIconIdle = "mic.slash.fill"
        static let micIconActive = "waveform"
        static let arrow = "arrow.left.arrow.right"

        static let statusListening = "Listening"
        static let statusPaused = "Paused"
        static let statusPreparing = "Preparing translation..."
        static let micToggleStart = "Start listening"
        static let micToggleStop = "Stop listening"
        static let micDisabledHelp = "Waiting for translation model to finish downloading"

        static let downloadChecking = "Checking translation models..."
        static let downloadInProgress = "Downloading translation models"
        static let downloadFailed = "Translation download failed"
        static let downloadSubtitle = "First-run only. This may take a few minutes. The model stays on your device for offline use."
        static let downloadEstimateSuffix = "estimated"
        static let downloadElapsedFormat = "%ds elapsed"
        static let retry = "Retry"

        static let historyTitle = "History"
        static let historyEmpty = "No translations yet. Start speaking Chinese."
        static let historyClearAll = "Clear all"
        static let historyDelete = "Delete entry"
        static let historyCountFormat = "%d entries"

        static let downloadTakingLong = "Taking longer than expected. Tap Cancel and retry if the download appears stuck."
        static let downloadCancel = "Cancel and retry"
    }

    enum Error {
        static let micDenied = "Microphone access denied. Enable in System Settings."
        static let speechDenied = "Speech recognition denied. Enable in System Settings."
        static let recognizerUnavailable = "Chinese speech recognizer unavailable on this device."
        static let recognizerKeepsFailing = "Speech recognition keeps failing. Tap the mic to try again."

        /// Used when LanguageAvailability reports `.unsupported`.
        static let translationLanguagePairUnsupported = "Chinese ↔ English translation isn't available on this Mac. macOS 15 or later is required."
        /// Used when waitUntilInstalled exceeds its retry budget.
        static let translationDownloadTimeout = "Translation model download timed out. Check your internet connection and retry."
        /// Used when prepareTranslation throws (system error).
        static let translationPrepareFailedFormat = "Translation could not be prepared: %@"
    }
}
