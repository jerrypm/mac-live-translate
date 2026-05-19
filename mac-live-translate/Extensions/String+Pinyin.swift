//
//  String+Pinyin.swift
//  mac-live-translate
//
//  Created by JPM on 19/05/26.
//
//  Mandarin pinyin (with tone marks) for Chinese characters - used to show
//  pronunciation under the live source pane, like Google Translate does.
//
//  Uses Apple's `CFStringTransform` with `kCFStringTransformMandarinLatin`:
//  100% on-device, no network, no extra dependency. Non-Chinese characters
//  pass through unchanged so mixed input is safe.
//

import Foundation

extension String {

    /// Lower-case pinyin with tone marks. Empty string when the input is empty.
    var pinyin: String {
        guard !isEmpty else { return "" }
        let mutable = NSMutableString(string: self)
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        return mutable as String
    }

    /// Pinyin with the first letter capitalised, matching the Google-Translate
    /// presentation ("Nǐ hǎo ma" rather than "nǐ hǎo ma").
    var pinyinDisplay: String {
        let raw = pinyin
        guard let first = raw.first else { return "" }
        return String(first).uppercased() + raw.dropFirst()
    }
}
