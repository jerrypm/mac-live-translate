//
//  StringChineseTests.swift
//  mac-live-translateTests
//
//  Covers CJK detection used to filter non-Chinese noise from the recognizer.
//

import XCTest
@testable import mac_live_translate

final class StringChineseTests: XCTestCase {

    func test_emptyString_returnsFalse() {
        XCTAssertFalse("".containsChinese)
    }

    func test_englishOnly_returnsFalse() {
        XCTAssertFalse("Hello world".containsChinese)
        XCTAssertFalse("123 abc".containsChinese)
    }

    func test_pureSimplifiedChinese_returnsTrue() {
        XCTAssertTrue("你好".containsChinese)
        XCTAssertTrue("你别言我呀来打我呀笨蛋".containsChinese)
    }

    func test_traditionalChinese_returnsTrue() {
        XCTAssertTrue("繁體中文".containsChinese)
    }

    func test_mixedChineseAndLatin_returnsTrue() {
        XCTAssertTrue("Hello 你好".containsChinese)
        XCTAssertTrue("test 测试 123".containsChinese)
    }

    func test_punctuationOnly_returnsFalse() {
        XCTAssertFalse("...!?,.".containsChinese)
    }

    func test_japaneseHiraganaOnly_returnsFalse() {
        // Hiragana is outside our CJK range; intentional - only Chinese ideographs match.
        XCTAssertFalse("こんにちは".containsChinese)
    }

    func test_cjkExtensionA_returnsTrue() {
        // U+3400 (㐀) is in CJK Extension A range.
        XCTAssertTrue("㐀".containsChinese)
    }
}
