//
//  LanguagePillsRow.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Static source/target language indicators at the top of the screen.
//  Currently fixed to Chinese (Simplified) → English; lifted into its own
//  view so a language-picker can replace it later without touching layout.
//

import SwiftUI

struct LanguagePillsRow: View {

    var body: some View {
        HStack(spacing: Metrics.Spacing.medium) {
            pill(text: Strings.UI.sourceLanguageLabel)
            Image(systemName: Strings.UI.arrow)
                .foregroundStyle(.secondary)
            pill(text: Strings.UI.targetLanguageLabel)
            Spacer()
        }
    }

    private func pill(text: String) -> some View {
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
}
