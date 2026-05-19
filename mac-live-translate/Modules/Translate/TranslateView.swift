//
//  TranslateView.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Google-Translate-style layout: source (zh) left, target (en) right.
//  Mic toggle bottom-left. In-app overlay covers the Apple download sheet
//  cycle so the user always sees status (checking / downloading / ready / failed).
//  Mic is disabled until the model is fully installed.
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
                downloadOverlay
            }
        }
        .translationTask(translationConfig) { session in
            await translationService.attach(session)
        }
        .onAppear {
            translationConfig = translationService.makeConfiguration()
            presenter.viewAppeared()
        }
        .onDisappear {
            presenter.viewDisappeared()
            translationService.detach()
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: Metrics.Spacing.medium) {
            languagePillsRow

            HStack(spacing: Metrics.Spacing.medium) {
                sourceBox
                targetBox
            }

            if let error = presenter.state.errorMessage {
                errorBanner(error)
            }

            HStack {
                micToggleButton
                Spacer()
                statusLabel
            }
        }
        .padding(Metrics.Spacing.large)
        .frame(
            minWidth: Metrics.Size.minWindowWidth,
            minHeight: Metrics.Size.minWindowHeight
        )
    }

    // MARK: - Language pills

    private var languagePillsRow: some View {
        HStack(spacing: Metrics.Spacing.medium) {
            languagePill(text: Strings.UI.sourceLanguageLabel)
            Image(systemName: Strings.UI.arrow)
                .foregroundStyle(.secondary)
            languagePill(text: Strings.UI.targetLanguageLabel)
            Spacer()
        }
    }

    private func languagePill(text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.tint)
            .padding(.horizontal, Metrics.Spacing.medium)
            .frame(height: Metrics.Size.languagePillHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.Corner.pill)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }

    // MARK: - Text boxes

    private var sourceBox: some View {
        textBox(
            text: presenter.state.sourceText,
            placeholder: Strings.UI.sourcePlaceholder,
            isPlaceholder: presenter.state.sourceText.isEmpty
        )
    }

    private var targetBox: some View {
        textBox(
            text: presenter.state.translatedText,
            placeholder: Strings.UI.targetPlaceholder,
            isPlaceholder: presenter.state.translatedText.isEmpty
        )
        .background(
            RoundedRectangle(cornerRadius: Metrics.Corner.textBox)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func textBox(text: String, placeholder: String, isPlaceholder: Bool) -> some View {
        ScrollView {
            Text(isPlaceholder ? placeholder : text)
                .font(.title2)
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(Metrics.Spacing.medium)
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.Size.textBoxMinHeight, alignment: .topLeading)
    }

    // MARK: - Mic toggle

    private var micToggleButton: some View {
        Button {
            presenter.toggleListening()
        } label: {
            Image(systemName: micIcon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(micIconColor)
                .frame(width: Metrics.Size.micButton, height: Metrics.Size.micButton)
                .symbolEffect(.pulse, options: .repeating, isActive: presenter.state.isListening)
        }
        .buttonStyle(.plain)
        .disabled(!presenter.canListen)
        .help(micHelp)
    }

    private var micIcon: String {
        if !presenter.canListen { return Strings.UI.micIconIdle }
        return presenter.state.isListening
            ? Strings.UI.micIconActive
            : Strings.UI.micIconIdle
    }

    private var micIconColor: Color {
        if !presenter.canListen { return .secondary.opacity(0.4) }
        return presenter.state.isListening ? Color.accentColor : .secondary
    }

    private var micHelp: String {
        if !presenter.canListen { return Strings.UI.micDisabledHelp }
        return presenter.state.isListening
            ? Strings.UI.micToggleStop
            : Strings.UI.micToggleStart
    }

    private var statusLabel: some View {
        Text(statusText)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var statusText: String {
        if !presenter.canListen {
            return Strings.UI.statusPreparing
        }
        return presenter.state.isListening
            ? Strings.UI.statusListening
            : Strings.UI.statusPaused
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(Metrics.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.Corner.pill)
                    .fill(Color.red.opacity(0.08))
            )
    }

    // MARK: - Download overlay

    private var shouldShowDownloadOverlay: Bool {
        switch presenter.state.downloadState {
        case .checking, .downloading, .failed:
            return true
        case .idle, .ready:
            return false
        }
    }

    private var downloadOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: Metrics.Spacing.medium) {
                ProgressView()
                    .controlSize(.large)
                Text(overlayTitle)
                    .font(.headline)
                Text(Strings.UI.downloadSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                if case .failed = presenter.state.downloadState {
                    Button(Strings.UI.retry) {
                        presenter.viewAppeared()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(Metrics.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: Metrics.Corner.textBox)
                    .fill(.regularMaterial)
            )
            .padding(Metrics.Spacing.large)
        }
        .transition(.opacity)
    }

    private var overlayTitle: String {
        switch presenter.state.downloadState {
        case .checking:    return Strings.UI.downloadChecking
        case .downloading: return Strings.UI.downloadInProgress
        case .failed:      return Strings.UI.downloadFailed
        case .idle, .ready: return ""
        }
    }
}
