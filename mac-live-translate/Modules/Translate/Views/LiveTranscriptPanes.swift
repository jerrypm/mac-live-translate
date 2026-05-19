//
//  LiveTranscriptPanes.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Side-by-side panes showing the in-progress (not yet finalized) Chinese
//  transcript and its English translation. Finalized utterances move to
//  the history list below.
//

import SwiftUI

struct LiveTranscriptPanes: View {

    let sourceText: String
    let translatedText: String

    var body: some View {
        HStack(spacing: Metrics.Spacing.medium) {
            TextPaneBox(
                text: sourceText,
                placeholder: Strings.UI.sourcePlaceholder
            )
            TextPaneBox(
                text: translatedText,
                placeholder: Strings.UI.targetPlaceholder,
                background: AnyShapeStyle(Color.secondary.opacity(0.08))
            )
        }
    }
}
