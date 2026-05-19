//
//  SpeechRecognitionService.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Wraps Apple Speech framework for continuous on-device Chinese (zh-CN)
//  recognition. Auto-restarts after each final utterance for live-feel.
//  Restarts on transient errors are rate-limited so a broken recognizer
//  cannot hot-loop.
//

import AVFoundation
import OSLog
import Speech

@MainActor
final class SpeechRecognitionService: SpeechRecognizing {

    // MARK: - Callbacks

    var onTranscript: ((String, _ isFinal: Bool) -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - State

    private(set) var isRunning = false

    // MARK: - Tuning

    /// "No speech detected" is a normal silence - don't count against the limit.
    private let silenceErrorCode = 1110
    /// Max consecutive non-silence error restarts before giving up.
    private let maxConsecutiveErrorRestarts = 5

    // MARK: - Private

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var consecutiveErrorRestarts = 0

    // MARK: - Init

    init(localeIdentifier: String? = nil) {
        let id = localeIdentifier ?? Strings.Locale.sourceChinese
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: id))
    }

    // MARK: - Public API

    func requestAuthorizationAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                switch status {
                case .authorized:
                    self.start()
                case .denied, .restricted, .notDetermined:
                    self.onError?(Strings.Error.speechDenied)
                @unknown default:
                    self.onError?(Strings.Error.speechDenied)
                }
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        guard let recognizer, recognizer.isAvailable else {
            onError?(Strings.Error.recognizerUnavailable)
            return
        }

        consecutiveErrorRestarts = 0

        do {
            try beginSession(using: recognizer)
            isRunning = true
            Logger.speech.info("Recognition session started")
        } catch {
            Logger.speech.error("Failed to start: \(error.localizedDescription)")
            onError?(error.localizedDescription)
        }
    }

    func stop() {
        guard isRunning else { return }
        teardownAudio()
        task?.cancel()
        task = nil
        isRunning = false
        consecutiveErrorRestarts = 0
        Logger.speech.info("Recognition session stopped")
    }

    // MARK: - Session

    private func beginSession(using recognizer: SFSpeechRecognizer) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // SFSpeechRecognitionTask's completion may fire on a background queue.
        // Hop to the main actor explicitly before touching any class state.
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleRecognitionCallback(result: result, error: error)
            }
        }
    }

    private func handleRecognitionCallback(
        result: SFSpeechRecognitionResult?,
        error: Error?
    ) {
        if let result {
            consecutiveErrorRestarts = 0
            let text = result.bestTranscription.formattedString
            onTranscript?(text, result.isFinal)

            if result.isFinal {
                restartSession()
            }
        }

        if let error {
            let nsError = error as NSError
            if nsError.code == silenceErrorCode {
                // Silence is normal - free restart.
                restartSession()
                return
            }

            consecutiveErrorRestarts += 1
            Logger.speech.error("Recognition error (\(self.consecutiveErrorRestarts)/\(self.maxConsecutiveErrorRestarts)): \(error.localizedDescription)")

            if consecutiveErrorRestarts >= maxConsecutiveErrorRestarts {
                Logger.speech.error("Hit max consecutive error restarts - giving up")
                teardownAudio()
                task = nil
                isRunning = false
                consecutiveErrorRestarts = 0
                onError?(Strings.Error.recognizerKeepsFailing)
                return
            }

            restartSession()
        }
    }

    private func restartSession() {
        guard isRunning else { return }
        teardownAudio()
        task = nil
        request = nil

        guard let recognizer, recognizer.isAvailable else { return }
        do {
            try beginSession(using: recognizer)
        } catch {
            Logger.speech.error("Restart failed: \(error.localizedDescription)")
            isRunning = false
            onError?(error.localizedDescription)
        }
    }

    private func teardownAudio() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
    }
}
