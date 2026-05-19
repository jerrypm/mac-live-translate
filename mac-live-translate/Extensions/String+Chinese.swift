//
//  String+Chinese.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Helpers for detecting Chinese (CJK) characters - used to filter
//  non-Chinese speech noise from the Chinese-locale recognizer.
//

import Foundation

extension String {

    /// True when the string contains at least one CJK Unified Ideograph.
    /// Range U+4E00–U+9FFF covers common Chinese characters.
    var containsChinese: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
                || (0x20000...0x2A6DF).contains(scalar.value)
        }
    }
}
