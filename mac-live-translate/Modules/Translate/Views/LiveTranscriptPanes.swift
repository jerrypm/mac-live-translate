//
//  LiveTranscriptPanes.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Side-by-side panes showing the in-progress (not yet finalized) Chinese
//  transcript and its English translation. Pinyin appears under the source
//  pane so the user knows how to pronounce what they're hearing. An Add
//  button on the translation pane lets the user snapshot the current
//  utterance into history without pausing the mic.
//

import SwiftUI

struct LiveTranscriptPanes: View {

    let sourceText: String
    let translatedText: String
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Spacing.medium) {
            TextPaneBox(
                text: sourceText,
                placeholder: Strings.UI.sourcePlaceholder,
                subtitle: sourceText.pinyinDisplay
            )

            translationPaneWithAddButton
        }
    }

    /// The translation pane is wrapped in a ZStack so the Add button can sit
    /// in the top-right corner without disturbing the pane's own scroll view.
    private var translationPaneWithAddButton: some View {
        ZStack(alignment: .topTrailing) {
            TextPaneBox(
                text: translatedText,
                placeholder: Strings.UI.targetPlaceholder,
                background: AnyShapeStyle(Color.secondary.opacity(0.08))
            )

            addButton
                .padding(Metrics.Spacing.small)
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Label(Strings.UI.addToHistory, systemImage: "plus.circle.fill")
                .font(.footnote.weight(.medium))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderless)
        .disabled(!canAdd)
        .help(Strings.UI.addToHistoryHelp)
    }
}
