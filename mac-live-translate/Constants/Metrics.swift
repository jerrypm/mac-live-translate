//
//  Metrics.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Layout constants - spacing, sizes, durations.
//  Named `Metrics` to avoid clash with SwiftUI's `Layout` protocol.
//

import Foundation
import CoreGraphics

enum Metrics {

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Size {
        static let minWindowWidth: CGFloat = 720
        static let minWindowHeight: CGFloat = 360
        static let textBoxMinHeight: CGFloat = 200
        static let micButton: CGFloat = 36
        static let languagePillHeight: CGFloat = 36
    }

    enum Corner {
        static let textBox: CGFloat = 12
        static let pill: CGFloat = 8
    }

    enum Duration {
        /// Debounce window between partial transcripts before kicking translation.
        static let translateDebounce: TimeInterval = 0.3
        /// Pulse animation period for active mic indicator.
        static let pulse: TimeInterval = 1.0
    }
}
