//
//  AppLogger.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Centralized OSLog logger. Filter by category in Console.app.
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jerrypm.mac-live-translate"

    static let app         = Logger(subsystem: subsystem, category: "App")
    static let speech      = Logger(subsystem: subsystem, category: "Speech")
    static let translation = Logger(subsystem: subsystem, category: "Translation")
    static let ui          = Logger(subsystem: subsystem, category: "UI")
}
