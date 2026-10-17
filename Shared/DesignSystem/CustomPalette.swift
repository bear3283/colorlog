//
//  CustomPalette.swift
//  colorlog (앱 · 위젯 공용)
//
//  사용자가 직접 고른 다섯 색. `ColorPalette.custom`이 이 값을 읽는다.
//
//  앱과 위젯이 함께 쓰는 App Group 설정에 "HEX,HEX,..." 한 줄로 둔다.
//  한 줄 문자열이라 @AppStorage로 바로 묶이고, 값이 바뀌면 그걸 보는 화면이 다시 그려진다.
//
//  색을 바꿔도 지난 기록은 그대로다. 기록은 고른 순간의 HEX를 저장하기 때문이다.
//

import SwiftUI

nonisolated enum CustomPalette {

    /// App Group 설정 키.
    static let key = "colorlog.customPalette"

    /// 처음 열었을 때의 다섯 색. 앱 아이콘 곰의 색(수채 곰)에서 출발한다.
    static var defaultHexes: [String] { ColorPalette.watercolor.swatches.map(\.hex) }

    /// 지금 저장된 다섯 색. 비어 있거나 망가졌으면 기본 다섯 색.
    static var hexes: [String] {
        decode(ColorLogStore.defaults.string(forKey: key) ?? "")
    }

    static func decode(_ stored: String) -> [String] {
        let parsed = stored.split(separator: ",").compactMap { HexColor.normalized(String($0)) }
        guard parsed.count == 5 else { return defaultHexes }
        return parsed
    }

    static func encode(_ hexes: [String]) -> String {
        hexes.joined(separator: ",")
    }

    // MARK: 색상 · 진하기

    /// 편집기의 두 손잡이(색상 · 진하기)로 만드는 색.
    ///
    /// 수채 물감처럼 생각한다. 진하기 0은 물을 잔뜩 탄 옅은 색, 1은 물감이 고인 진한 색.
    /// 진해질수록 채도는 오르고 밝기는 내려간다.
    static func color(hue: Double, depth: Double) -> String {
        let d = min(max(depth, 0), 1)
        let saturation = 0.32 + 0.56 * d
        let lightness = 0.86 - 0.44 * d
        return HexColor.hex(hue: hue, saturation: saturation, lightness: lightness)
    }

    /// 아무 HEX를 두 손잡이의 위치로 되돌린다. 시스템 색상 선택기에서 고른 색도
    /// 손잡이가 그 근처에 놓이도록. 정확히 같은 색이 나오지는 않을 수 있다.
    static func handles(for hex: String) -> (hue: Double, depth: Double) {
        let hsl = HexColor.hsl(of: hex) ?? (0, 0.5, 0.6)
        let depth = (0.86 - hsl.lightness) / 0.44
        return (hsl.hue, min(max(depth, 0), 1))
    }
}

nonisolated extension HexColor {

    /// HSL(색상 0~360, 채도 · 밝기 0~1) → "#RRGGBB".
    static func hex(hue: Double, saturation: Double, lightness: Double) -> String {
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        let m = lightness - c / 2
        func byte(_ v: Double) -> Int { Int(((v + m) * 255).rounded()).clamped(to: 0...255) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    /// "#RRGGBB" → HSL(색상 0~360, 채도 · 밝기 0~1).
    static func hsl(of hex: String) -> (hue: Double, saturation: Double, lightness: Double)? {
        guard let c = components(from: hex) else { return nil }
        let r = c.red, g = c.green, b = c.blue
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        guard maxV != minV else { return (0, 0, l) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double = switch maxV {
        case r: (g - b) / d + (g < b ? 6 : 0)
        case g: (b - r) / d + 2
        default: (r - g) / d + 4
        }
        h *= 60
        return (h, s, l)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}
