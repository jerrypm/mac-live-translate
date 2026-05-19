//
//  TranslationEntry.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  One finalized utterance + its translation, recorded after the speech
//  recognizer marks an utterance as final.
//

import Foundation

struct TranslationEntry: Identifiable, Equatable {
    let id: UUID
    let chineseText: String
    let englishText: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        chineseText: String,
        englishText: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.chineseText = chineseText
        self.englishText = englishText
        self.timestamp = timestamp
    }
}
