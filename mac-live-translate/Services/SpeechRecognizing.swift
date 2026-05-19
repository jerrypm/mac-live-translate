//
//  SpeechRecognizing.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Abstraction over the Apple Speech framework so the interactor can be
//  unit-tested with a mock recognizer.
//

import Foundation

@MainActor
protocol SpeechRecognizing: AnyObject {

    /// Fires for every partial + final transcript update.
    var onTranscript: ((String, _ isFinal: Bool) -> Void)? { get set }

    /// Fires when an unrecoverable error occurs.
    var onError: ((String) -> Void)? { get set }

    var isRunning: Bool { get }

    /// Request authorization then start recognition. No-op if already running.
    func requestAuthorizationAndStart()

    /// Start recognition without prompting (caller already has authorization).
    func start()

    /// Stop recognition + release audio resources.
    func stop()
}
