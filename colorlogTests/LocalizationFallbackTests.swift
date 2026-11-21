//
//  LocalizationFallbackTests.swift
//  colorlogTests
//
//  한국어 기기는 한국어, 영어 기기는 영어, 그 밖의 언어(일본어 · 독일어 등)만 쓰는 기기는 영어.
//  iOS는 선호 언어 중 번들에 든 첫 언어를 고르고, 하나도 없으면 개발 언어(CFBundleDevelopmentRegion)로
//  떨어진다. 그래서 개발 언어가 en이고, ko.lproj · en.lproj가 둘 다 실려 있어야 이 규칙이 선다.
//  String Catalog의 원문 언어는 lproj로 컴파일되지 않으므로, 원문 언어가 ko로 돌아가면 ko.lproj가
//  사라져 한국어 기기까지 영어가 된다 — 그 회귀를 여기서 잡는다.
//

import Foundation
import Testing
@testable import colorlog

struct LocalizationFallbackTests {

    /// 테스트 호스트(colorlog.app)와 그 안의 위젯 확장.
    private static var bundles: [(name: String, bundle: Bundle)] {
        var result: [(String, Bundle)] = [("app", Bundle.main)]
        if let plugIns = Bundle.main.builtInPlugInsURL,
           let widget = Bundle(url: plugIns.appendingPathComponent("ColorLogWidgetsExtension.appex")) {
            result.append(("widget", widget))
        }
        return result
    }

    @Test("위젯 확장도 테스트 대상에 들어 있다")
    func widgetBundleIsPresent() {
        #expect(Self.bundles.map(\.name) == ["app", "widget"])
    }

    @Test("앱 · 위젯 모두 개발 언어는 영어, 실린 언어는 한국어 · 영어")
    func developmentRegionIsEnglish() {
        for (name, bundle) in Self.bundles {
            #expect(bundle.developmentLocalization == "en", "\(name)")
            #expect(bundle.infoDictionary?["CFBundleDevelopmentRegion"] as? String == "en", "\(name)")
            #expect(Set(bundle.localizations).isSuperset(of: ["ko", "en"]), "\(name): \(bundle.localizations)")
        }
    }

    @Test(
        "기기 선호 언어별로 번들이 고르는 언어",
        arguments: [
            (["ko-KR"], "ko"),
            (["en-US"], "en"),
            (["en-GB"], "en"),
            (["ja-JP"], "en"),
            (["de-DE"], "en"),
            (["ja-JP", "de-DE"], "en"),
            (["ja-JP", "ko-KR"], "ko"),   // 지원 언어가 뒤에라도 있으면 그 언어
            (["de-DE", "en-US", "ko-KR"], "en"),
        ]
    )
    func preferredLocalization(preferences: [String], expected: String) {
        for (name, bundle) in Self.bundles {
            let chosen = Self.chosenLocalization(in: bundle, preferences: preferences)
            #expect(chosen == expected, "\(name) \(preferences) → \(chosen)")
        }
    }

    @Test("영어 표에는 한국어 표의 모든 키가 있다(미지원 언어 기기에 한국어가 새지 않음)")
    func englishCoversEveryKey() throws {
        for (name, bundle) in Self.bundles {
            let ko = try Self.keys(in: bundle, localization: "ko")
            let en = try Self.keys(in: bundle, localization: "en")
            #expect(!ko.isEmpty, "\(name)")
            #expect(ko.subtracting(en).isEmpty, "\(name): \(ko.subtracting(en).sorted())")
        }
    }

    @Test("같은 키가 언어마다 제 값으로 풀린다", arguments: [
        ("칼라베어", "칼라베어", "ColorBear"),
        ("아침", "아침", "Morning"),
    ])
    func lookupPerLanguage(key: String, korean: String, english: String) throws {
        for (name, bundle) in Self.bundles {
            let ko = try #require(Self.lproj(bundle, "ko"), "\(name)")
            let en = try #require(Self.lproj(bundle, "en"), "\(name)")
            #expect(ko.localizedString(forKey: key, value: nil, table: nil) == korean, "\(name)")
            #expect(en.localizedString(forKey: key, value: nil, table: nil) == english, "\(name)")
        }
    }

    @Test("홈 화면 이름: 한국어 칼라베어, 영어 ColorBear")
    func displayName() throws {
        for (name, bundle) in Self.bundles {
            let ko = try #require(Self.lproj(bundle, "ko"), "\(name)")
            let en = try #require(Self.lproj(bundle, "en"), "\(name)")
            #expect(ko.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist") == "칼라베어", "\(name)")
            #expect(en.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist") == "ColorBear", "\(name)")
        }
    }

    // MARK: - 도우미

    /// iOS가 번들 언어를 고르는 규칙: 선호 언어 순서대로 번들에 든 첫 언어, 없으면 개발 언어.
    private static func chosenLocalization(in bundle: Bundle, preferences: [String]) -> String {
        let available = bundle.localizations.filter { $0 != "Base" }
        let matched = Bundle.preferredLocalizations(from: available, forPreferences: preferences)
        // 선호 언어가 하나도 맞지 않을 때 Foundation이 돌려주는 값은 문서상 '번들 언어 중 하나'라
        // 개발 언어인지 함께 확인한다.
        let anyMatch = preferences.contains { pref in
            available.contains { pref.hasPrefix($0) || $0.hasPrefix(pref) }
        }
        if !anyMatch { #expect(matched.first == bundle.developmentLocalization) }
        return matched.first ?? bundle.developmentLocalization ?? "?"
    }

    private static func lproj(_ bundle: Bundle, _ localization: String) -> Bundle? {
        bundle.path(forResource: localization, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    private static func keys(in bundle: Bundle, localization: String) throws -> Set<String> {
        var keys = Set<String>()
        for file in ["Localizable.strings", "Localizable.stringsdict"] {
            guard let url = bundle.url(forResource: localization, withExtension: "lproj")?
                .appendingPathComponent(file),
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
            if let table = plist as? [String: Any] { keys.formUnion(table.keys) }
        }
        return keys
    }
}
