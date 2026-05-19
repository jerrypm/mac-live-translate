//
//  TranslateView.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Top-level composition for the Translate module. Lays out the
//  language pills, live transcript panes, mic toggle, error banner,
//  history list, and the download overlay (when applicable).
//
//  Concrete sub-views live in `Views/`. This file only wires them to the
//  presenter and handles the SwiftUI-specific retry dance for
//  `.translationTask`.
//

import SwiftUI
import Translation

struct TranslateView: View {

    @State var presenter: TranslatePresenter
    let translationService: TranslationService

    @State private var translationConfig: TranslationSession.Configuration?

    var body: some View {
        ZStack {
            mainContent
            if shouldShowDownloadOverlay {
                DownloadOverlay(
                    downloadState: presenter.state.downloadState,
                    progress: presenter.state.downloadProgress,
                    onRetry: performRetry
                )
            }
        }
        .translationTask(translationConfig) { session in
            await translationService.attach(session)
        }
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
    }

    // MARK: - Composition

    private var mainContent: some View {
        VStack(spacing: Metrics.Spacing.medium) {
            LanguagePillsRow()

            LiveTranscriptPanes(
                sourceText: presenter.state.sourceText,
                translatedText: presenter.state.translatedText
            )

            if let error = presenter.state.errorMessage {
                ErrorBanner(message: error)
            }

            MicToggleControl(
                isListening: presenter.state.isListening,
                canListen: presenter.canListen,
                onToggle: presenter.toggleListening
            )

            Divider()

            HistorySection(
                entries: presenter.state.history,
                onDelete: presenter.deleteHistoryEntry,
                onClearAll: presenter.clearHistory
            )
        }
        .padding(Metrics.Spacing.large)
        .frame(
            minWidth: Metrics.Size.minWindowWidth,
            minHeight: Metrics.Size.minWindowHeight
        )
    }

    // MARK: - Lifecycle

    private func handleAppear() {
        translationConfig = translationService.makeConfiguration()
        presenter.viewAppeared()
    }

    private func handleDisappear() {
        presenter.viewDisappeared()
        translationService.detach()
    }

    // MARK: - Retry / overlay visibility

    /// Retry needs to do three things in order:
    /// 1. Reset the service so its `checkAvailability` guard re-opens.
    /// 2. Drop the existing `translationConfig` so SwiftUI tears down the old
    ///    `.translationTask`, then assign a new configuration to make it
    ///    fire again — `attach(_:)` runs from scratch.
    /// 3. Tell the presenter to re-check availability + clear stale error UI.
    private func performRetry() {
        translationConfig = nil
        presenter.retryDownload()
        DispatchQueue.main.async {
            translationConfig = translationService.makeConfiguration()
        }
    }

    private var shouldShowDownloadOverlay: Bool {
        switch presenter.state.downloadState {
        case .checking, .downloading, .failed: return true
        case .idle, .ready:                    return false
        }
    }
}
