//
//  HexColor.swift
//  colorlog
//
//  앱의 모든 색상은 HEX 문자열을 단일 진실 원천으로 삼는다.
//  SwiftData에 저장되는 색, 팔레트 테마 토큰, 위젯으로 전달되는 색이
//  전부 같은 표현을 공유하도록 이 계층을 유일한 변환 통로로 사용한다.
//

import SwiftUI
import UIKit

/// HEX 문자열의 검증·정규화·분해를 담당하는 네임스페이스.
///
/// 프로젝트 기본값이 MainActor 격리이지만, 이 계층은 순수 값 변환이고
/// SwiftData 모델·위젯·백그라운드 컨텍스트에서도 호출되므로 `nonisolated`로 고정한다.
nonisolated enum HexColor {

    /// 파싱 결과. 0...1 범위의 sRGB 성분.
    struct Components: Hashable, Sendable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double
    }

    /// `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` 를 허용한다. (`#` 생략 가능)
    static func components(from hex: String) -> Components? {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.allSatisfy(\.isHexDigit) else { return nil }

        // 축약형(3·4자리)을 6·8자리로 확장한다. #E9A -> #EE99AA
        if raw.count == 3 || raw.count == 4 {
            raw = raw.map { "\($0)\($0)" }.joined()
        }
        guard raw.count == 6 || raw.count == 8,
              let value = UInt64(raw, radix: 16) else { return nil }

        if raw.count == 6 {
            return Components(
                red: Double((value & 0xFF0000) >> 16) / 255,
                green: Double((value & 0x00FF00) >> 8) / 255,
                blue: Double(value & 0x0000FF) / 255,
                alpha: 1
            )
        } else {
            return Components(
                red: Double((value & 0xFF00_0000) >> 24) / 255,
                green: Double((value & 0x00FF_0000) >> 16) / 255,
                blue: Double((value & 0x0000_FF00) >> 8) / 255,
                alpha: Double(value & 0x0000_00FF) / 255
            )
        }
    }

    static func isValid(_ hex: String) -> Bool {
        components(from: hex) != nil
    }

    /// 저장 직전에 호출한다. 어떤 표기로 들어오든 `#RRGGBB` 대문자 정규형으로 통일.
    /// 알파가 있으면 `#RRGGBBAA` 로 보존한다.
    static func normalized(_ hex: String) -> String? {
        guard let c = components(from: hex) else { return nil }
        let r = Int((c.red * 255).rounded())
        let g = Int((c.green * 255).rounded())
        let b = Int((c.blue * 255).rounded())
        if c.alpha >= 1 {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        let a = Int((c.alpha * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}

// MARK: - 색 혼합 (수채화 블렌딩의 수학)

nonisolated extension HexColor.Components {

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// sRGB 감마를 벗겨 선형 광량으로. 색을 '섞으려면' 반드시 이 공간에서 해야 한다.
    private static func toLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func toGamma(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    var linear: (r: Double, g: Double, b: Double) {
        (Self.toLinear(red), Self.toLinear(green), Self.toLinear(blue))
    }

    init(linear: (r: Double, g: Double, b: Double), alpha: Double = 1) {
        self.init(
            red: min(max(Self.toGamma(linear.r), 0), 1),
            green: min(max(Self.toGamma(linear.g), 0), 1),
            blue: min(max(Self.toGamma(linear.b), 0), 1),
            alpha: alpha
        )
    }

    /// 흰 물감을 섞듯 묽게. (물을 더 탄 느낌)
    func lightened(by amount: Double) -> Self {
        let l = linear
        return Self(linear: (
            l.r + (1 - l.r) * amount,
            l.g + (1 - l.g) * amount,
            l.b + (1 - l.b) * amount
        ), alpha: alpha)
    }

    /// 안료가 고인 자리처럼 진하게.
    func darkened(by amount: Double) -> Self {
        let l = linear
        let k = 1 - amount
        return Self(linear: (l.r * k, l.g * k, l.b * k), alpha: alpha)
    }
}

nonisolated extension HexColor {

    /// 여러 색을 가중치대로 선형 공간에서 섞는다.
    /// sRGB에서 직접 평균 내면 중간색이 회색빛으로 탁해지기 때문에 이 경로가 필요하다.
    static func blend(_ weighted: [(color: Components, weight: Double)]) -> Components {
        let total = weighted.reduce(0) { $0 + max($1.weight, 0) }
        guard total > 0 else {
            return weighted.first?.color ?? Components(red: 0, green: 0, blue: 0, alpha: 1)
        }

        var r = 0.0, g = 0.0, b = 0.0, a = 0.0
        for (color, rawWeight) in weighted {
            let w = max(rawWeight, 0) / total
            let l = color.linear
            r += l.r * w
            g += l.g * w
            b += l.b * w
            a += color.alpha * w
        }
        return Components(linear: (r, g, b), alpha: a)
    }
}

// MARK: - SwiftUI Color Bridge

nonisolated extension Color {

    /// 잘못된 HEX면 `nil`. 실패를 조용히 삼키지 않기 위해 failable로 둔다.
    init?(hex: String) {
        guard let c = HexColor.components(from: hex) else { return nil }
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }

    /// 파싱 실패 시 대체색으로 폴백. 팔레트 상수처럼 "절대 실패하지 않아야 하는" 곳에서만 사용.
    init(hex: String, fallback: Color) {
        self = Color(hex: hex) ?? fallback
    }

    /// ColorPicker 등에서 얻은 `Color`를 저장 가능한 HEX로 되돌린다.
    /// Display P3 같은 광색역 값은 sRGB 0...1로 클램프된다.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "#000000"
        }
        let clamp: (CGFloat) -> Int = { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }
}
