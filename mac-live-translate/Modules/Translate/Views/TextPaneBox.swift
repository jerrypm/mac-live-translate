//
//  TextPaneBox.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Reusable read-only text pane that swaps to a secondary-styled placeholder
//  when empty. Used for both the live source (zh) and translation (en) panes.
//

import SwiftUI

struct TextPaneBox: View {

    let text: String
    let placeholder: String
    var background: AnyShapeStyle?

    var body: some View {
        ScrollView {
            Text(displayText)
                .font(.title2)
                .foregroundStyle(displayColor)
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

    private var isPlaceholder: Bool { text.isEmpty }

    private var displayText: String { isPlaceholder ? placeholder : text }

    private var displayColor: Color { isPlaceholder ? .secondary : .primary }

    @ViewBuilder
    private var backgroundShape: some View {
        if let background {
            RoundedRectangle(cornerRadius: Metrics.Corner.textBox)
                .fill(background)
        }
    }
}
