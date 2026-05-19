//
//  TextPaneBox.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Reusable read-only text pane that swaps to a secondary-styled placeholder
//  when empty. Optionally shows a small subtitle line under the main text
//  (used to display pinyin under the live Chinese source).
//

import SwiftUI

struct TextPaneBox: View {

    let text: String
    let placeholder: String
    var subtitle: String? = nil
    var background: AnyShapeStyle? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Spacing.small / 2) {
                Text(displayText)
                    .font(.title2)
                    .foregroundStyle(displayColor)

                if shouldShowSubtitle, let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(Metrics.Spacing.medium)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: Metrics.Size.textBoxMinHeight,
            alignment: .topLeading
        )
        .background(backgroundShape)
    }

    // MARK: - Display rules

    private var isPlaceholder: Bool { text.isEmpty }

    private var displayText: String { isPlaceholder ? placeholder : text }

    private var displayColor: Color { isPlaceholder ? .secondary : .primary }

    /// Hide the subtitle while the pane is showing its placeholder; subtitles
    /// only make sense once we have real content.
    private var shouldShowSubtitle: Bool {
        !isPlaceholder && !(subtitle ?? "").isEmpty
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if let background {
            RoundedRectangle(cornerRadius: Metrics.Corner.textBox)
                .fill(background)
        }
    }
}
