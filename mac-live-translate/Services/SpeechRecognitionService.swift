//
//  SpeechRecognitionService.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Wraps Apple Speech framework for continuous on-device Chinese (zh-CN)
//  recognition. Auto-restarts after each final utterance for live-feel.
//

import AVFoundation
import OSLog
import Speech

@MainActor
final class SpeechRecognitionService: SpeechRecognizing {

    // MARK: - Callbacks

    /// Fires on every partial + final transcript update with the raw recognized text.
    var onTranscript: ((String, _ isFinal: Bool) -> Void)?

    /// Fires when an unrecoverable error occurs.
    var onError: ((String) -> Void)?

    // MARK: - State

    private(set) var isRunning = false

    // MARK: - Private

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

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
                case .denied, .restricted:
                    self.onError?(Strings.Error.speechDenied)
                case .notDetermined:
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
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRunning = false
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

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.onTranscript?(text, result.isFinal)

                if result.isFinal {
                    self.restartSession()
                }
            }

            if let error {
                let nsError = error as NSError
                // Code 1110 = "No speech detected" - normal silence, just restart.
                if nsError.code == 1110 {
                    self.restartSession()
                } else {
                    Logger.speech.error("Recognition error: \(error.localizedDescription)")
                    self.restartSession()
                }
            }
        }
    }

    private func restartSession() {
        guard isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
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
}
