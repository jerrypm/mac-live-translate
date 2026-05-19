//
//  DownloadProgressTicker.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Emits a time-based `DownloadProgress` while the model download is in
//  flight. Apple's framework doesn't expose real byte progress - this is
//  the most honest estimate we can give the user.
//

import Foundation

@MainActor
final class DownloadProgressTicker {

    /// Fires each tick (~1 Hz by default) with the latest estimate.
    var onTick: ((DownloadProgress) -> Void)?

    private let config: TranslationDownloadConfig
    private var task: Task<Void, Never>?
    private var startedAt: Date?

    init(config: TranslationDownloadConfig = TranslationDownloadConfig()) {
        self.config = config
    }

    func start() {
        guard task == nil else { return }

        startedAt = Date()
        emitInitialTick()
        task = makeTickerTask()
    }

    func stop() {
        task?.cancel()
        task = nil
        startedAt = nil
    }

    // MARK: - Internals

    private func emitInitialTick() {
        onTick?(DownloadProgress(elapsedSeconds: 0, estimatedPercent: 1))
    }

    private func makeTickerTask() -> Task<Void, Never> {
        let interval = config.progressTickerInterval
        return Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await MainActor.run { self?.tick() }
            }
        }
    }

    private func tick() {
        guard let start = startedAt else { return }
        let elapsed = Date().timeIntervalSince(start)
        let pct = estimatedPercent(forElapsed: elapsed)
        onTick?(DownloadProgress(elapsedSeconds: Int(elapsed), estimatedPercent: pct))
    }

    private func estimatedPercent(forElapsed elapsed: TimeInterval) -> Int {
        let raw = (elapsed / config.expectedDownloadSeconds) * Double(config.maxEstimatedPercent)
        return min(config.maxEstimatedPercent, Int(raw))
    }
}
