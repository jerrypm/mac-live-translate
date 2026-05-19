//
//  ErrorBanner.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Inline red banner for surface-level errors (speech-denied, recognizer
//  unavailable, etc.). Stale download errors are cleared by the presenter
//  on recovery transitions; this view just renders whatever it's given.
//

import SwiftUI

struct ErrorBanner: View {

    let message: String

    var body: some View {
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
}
