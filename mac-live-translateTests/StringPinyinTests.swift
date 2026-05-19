//
//  StringPinyinTests.swift
//  mac-live-translateTests
//
//  Verifies the pinyin transform used to render pronunciation under
//  Chinese characters in the live source pane.
//

import XCTest
@testable import mac_live_translate

final class StringPinyinTests: XCTestCase {

    func test_pinyin_emptyString_isEmpty() {
        XCTAssertEqual("".pinyin, "")
        XCTAssertEqual("".pinyinDisplay, "")
    }

    func test_pinyin_simpleGreeting_returnsToneMarkedPinyin() {
        let result = "你好".pinyin
        XCTAssertTrue(result.contains("nǐ"), "Expected `nǐ` in `\(result)`")
        XCTAssertTrue(result.contains("hǎo"), "Expected `hǎo` in `\(result)`")
    }

    func test_pinyinDisplay_capitalisesFirstLetterOnly() {
        let result = "你好".pinyinDisplay
        XCTAssertTrue(result.hasPrefix("N"), "Expected leading capital N in `\(result)`")
        XCTAssertFalse(result.contains("HǍO"), "Only the first letter should be capitalised")
    }

    func test_pinyin_longerSentence_retainsToneMarks() {
        let result = "你好吗".pinyin
        XCTAssertTrue(result.contains("nǐ"))
        XCTAssertTrue(result.contains("hǎo"))
        XCTAssertTrue(result.contains("ma"))
    }
}
