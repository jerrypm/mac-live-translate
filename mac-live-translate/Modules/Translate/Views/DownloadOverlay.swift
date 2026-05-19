//
//  DownloadOverlay.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Modal overlay shown while the translation model is checking/downloading
//  or after a failure. Renders progress, "taking longer" warning, and a
//  context-sensitive action button (Retry on failure, Cancel-and-retry on
//  long-running download).
//

import SwiftUI

struct DownloadOverlay: View {

    let downloadState: TranslationDownloadState
    let progress: DownloadProgress
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            card
        }
        .transition(.opacity)
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: Metrics.Spacing.medium) {
            Text(title).font(.headline)
            primaryIndicator
            Text(Strings.UI.downloadSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if isTakingLong {
                takingLongHint
            }
            actionButton
        }
        .padding(Metrics.Spacing.large)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: Metrics.Corner.textBox).fill(.regularMaterial)
        )
        .padding(Metrics.Spacing.large)
    }

    private var title: String {
        switch downloadState {
        case .checking:     return Strings.UI.downloadChecking
        case .downloading:  return Strings.UI.downloadInProgress
        case .failed:       return Strings.UI.downloadFailed
        case .idle, .ready: return ""
        }
    }

    // MARK: - Indicator

    @ViewBuilder
    private var primaryIndicator: some View {
        switch downloadState {
        case .downloading:
            progressBar
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
        case .checking, .idle, .ready:
            ProgressView().controlSize(.large)
        }
    }

    private var progressBar: some View {
        VStack(spacing: Metrics.Spacing.small) {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .frame(maxWidth: 320)

            HStack {
                Text("\(progress.estimatedPercent)% \(Strings.UI.downloadEstimateSuffix)")
                    .font(.footnote.weight(.medium))
                Spacer()
                Text(String(format: Strings.UI.downloadElapsedFormat, progress.elapsedSeconds))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 320)
        }
    }

    private var fraction: Double {
        Double(progress.estimatedPercent) / 100.0
    }

    // MARK: - Slow-download hint + action

    private var takingLongHint: some View {
        Text(Strings.UI.downloadTakingLong)
            .font(.footnote)
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
    }

    private var isTakingLong: Bool {
        if case .downloading = downloadState {
            return Double(progress.elapsedSeconds) >= Metrics.Duration.downloadLongThresholdSeconds
        }
        return false
    }

    @ViewBuilder
    private var actionButton: some View {
        switch downloadState {
        case .failed:
            Button(Strings.UI.retry, action: onRetry)
                .buttonStyle(.borderedProminent)
        case .downloading where isTakingLong:
            Button(Strings.UI.downloadCancel, action: onRetry)
                .buttonStyle(.bordered)
        default:
            EmptyView()
        }
    }
}
