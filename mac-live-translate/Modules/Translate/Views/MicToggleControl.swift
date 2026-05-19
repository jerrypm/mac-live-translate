//
//  MicToggleControl.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Mic button + status label. Disabled until the translation model is
//  fully installed (otherwise listening would happen without translation).
//

import SwiftUI

struct MicToggleControl: View {

    let isListening: Bool
    let canListen: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            micButton
            Spacer()
            statusLabel
        }
    }

    // MARK: - Mic button

    private var micButton: some View {
        Button(action: onToggle) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: Metrics.Size.micButton, height: Metrics.Size.micButton)
                .symbolEffect(.pulse, options: .repeating, isActive: isListening)
        }
        .buttonStyle(.plain)
        .disabled(!canListen)
        .help(helpText)
    }

    private var iconName: String {
        guard canListen else { return Strings.UI.micIconIdle }
        return isListening ? Strings.UI.micIconActive : Strings.UI.micIconIdle
    }

    private var iconColor: Color {
        guard canListen else { return .secondary.opacity(0.4) }
        return isListening ? Color.accentColor : .secondary
    }

    private var helpText: String {
        guard canListen else { return Strings.UI.micDisabledHelp }
        return isListening ? Strings.UI.micToggleStop : Strings.UI.micToggleStart
    }

    // MARK: - Status

    private var statusLabel: some View {
        Text(statusText)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var statusText: String {
        guard canListen else { return Strings.UI.statusPreparing }
        return isListening ? Strings.UI.statusListening : Strings.UI.statusPaused
    }
}
