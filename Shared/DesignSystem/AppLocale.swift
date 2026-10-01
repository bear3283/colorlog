//
//  AppLocale.swift
//  colorlog
//

import Foundation

nonisolated extension Locale {
    /// 앱의 표기 언어.
    ///
    /// UI 문자열이 전부 한국어로 고정돼 있는데 날짜만 시스템 로케일을 따르면
    /// "September 2026" 옆에 "오늘" 버튼이 놓이는 어긋남이 생긴다.
    /// 다국어를 붙이는 시점에 이 값을 `.current`로 바꾸고 문자열을
    /// String Catalog로 옮기면 한 곳만 건드리면 된다.
    static let colorLog = Locale(identifier: "ko_KR")
}
