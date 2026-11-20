//
//  AppLocale.swift
//  colorlog
//

import Foundation

nonisolated extension Locale {
    /// 앱의 표기 언어.
    ///
    /// 날짜 · 시각 표기를 **화면 문자열과 같은 언어**로 맞춘다. 문자열이 한국어인데 날짜만
    /// 시스템 로케일을 따르면 "September 2026" 옆에 "오늘"이 놓이는 어긋남이 생긴다.
    ///
    /// 앱은 한국어(개발 언어)와 영어를 싣는다(`Shared/Localizable.xcstrings`).
    /// 시스템이 이 번들에 고른 언어(`preferredLocalizations`)가
    ///  · 한국어 → 한국 표기(ko_KR). 지원하지 않는 언어(일본어 등)도 한국어로 떨어진다.
    ///  · 영어  → 기기 지역 표기를 따르되 언어만 영어로(en_US, en_GB 등은 그대로, 다른 지역이면 en_지역).
    static let colorLog: Locale = {
        let language = Bundle.main.preferredLocalizations.first ?? "ko"
        guard language.hasPrefix("en") else { return Locale(identifier: "ko_KR") }
        if Locale.current.language.languageCode == .english { return .current }
        let region = Locale.current.region?.identifier
        return Locale(identifier: region.map { "en_\($0)" } ?? "en_US")
    }()
}
