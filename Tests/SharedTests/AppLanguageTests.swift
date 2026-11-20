import XCTest
@testable import Shared

final class AppLanguageTests: XCTestCase {
    func testKoreanPreferredLanguageSelectsKorean() {
        XCTAssertEqual(AppLanguage.defaultLanguage(preferredLanguages: ["ko-KR", "en-US"]), .korean)
        XCTAssertEqual(AppLanguage.defaultLanguage(preferredLanguages: ["ko"]), .korean)
        XCTAssertEqual(AppLanguage.defaultLanguage(preferredLanguages: ["ko_KR"]), .korean)
    }

    func testNonKoreanPreferredLanguageSelectsEnglish() {
        XCTAssertEqual(AppLanguage.defaultLanguage(preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(preferredLanguages: ["ja-JP", "ko-KR"]), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(preferredLanguages: []), .english)
    }
}
