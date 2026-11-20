//
//  SwatchOutline.swift
//  colorlog (앱 · 위젯 공용)
//
//  바탕과 거의 같은 밝기의 색 알에 두르는 얇은 먹선.
//
//  흰 종이 위의 레몬(구름 팔레트, 1.23:1)이나 수채 곰의 노랑(1.53:1)은 알의 윤곽이
//  사라져 '빈 자리'와 구분되지 않는다. 비텍스트 UI 대비 기준(WCAG 1.4.11, 3:1)에
//  못 미치는 색에만 선을 두른다. 색 자체(기록 HEX)는 바꾸지 않는다.
//

import SwiftUI

nonisolated extension HexColor {

    /// 앱 바탕(`Palette.appTheme`)의 HEX. 색 알 대비를 잴 기준.
    static let lightPaperHex = "#FFFFFF"
    static let darkPaperHex = "#121214"

    /// WCAG 상대 휘도. 잘못된 HEX면 nil.
    static func relativeLuminance(_ hex: String) -> Double? {
        guard let linear = components(from: hex)?.linear else { return nil }
        return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
    }

    /// WCAG 대비 비율(1...21). 둘 중 하나라도 잘못된 HEX면 nil.
    static func contrastRatio(_ a: String, _ b: String) -> Double? {
        guard let la = relativeLuminance(a), let lb = relativeLuminance(b) else { return nil }
        let (lighter, darker) = la > lb ? (la, lb) : (lb, la)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// 이 색 알이 바탕 위에서 윤곽선이 있어야 보이는가(대비 3:1 미만).
    /// 잘못된 HEX는 회색으로 그려지므로 선을 두르지 않는다.
    static func needsOutline(_ hex: String, on background: String, minimumContrast: Double = 3) -> Bool {
        guard let ratio = contrastRatio(hex, background) else { return false }
        return ratio < minimumContrast
    }
}

/// 대비가 모자란 색 알에만 먹선 한 겹. '대비 증가'를 켠 사용자에게는 모든 알에 두른다.
private struct SwatchOutline<S: InsettableShape>: ViewModifier {
    let hex: String
    let shape: S
    /// 알이 놓인 바탕. nil이면 앱 바탕(라이트 흰 종이 · 다크 먹빛).
    let backgroundHex: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var paperHex: String {
        backgroundHex ?? (colorScheme == .dark ? HexColor.darkPaperHex : HexColor.lightPaperHex)
    }

    private var isOutlined: Bool {
        contrast == .increased || HexColor.needsOutline(hex, on: paperHex)
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isOutlined {
                shape.strokeBorder(
                    colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.28),
                    lineWidth: contrast == .increased ? 1.5 : 1)
            }
        }
    }
}

extension View {
    /// 바탕과 대비가 3:1 미만인 색 알에 얇은 먹선을 두른다.
    func swatchOutline<S: InsettableShape>(
        hex: String, shape: S = Circle(), on backgroundHex: String? = nil
    ) -> some View {
        modifier(SwatchOutline(hex: hex, shape: shape, backgroundHex: backgroundHex))
    }
}

/// 색으로만 구분하지 않게, 팔레트 안에서 몇 번째 색인지 알리는 작은 모양.
/// '색상 없이 구별'(differentiateWithoutColor)을 켠 사용자에게만 보인다.
nonisolated enum SwatchMark {
    private static let symbols = [
        "circle.fill", "triangle.fill", "square.fill", "diamond.fill",
        "star.fill", "hexagon.fill", "heart.fill",
    ]

    /// 팔레트 안 순서(0부터)의 기호. 팔레트는 3~7색이라 모자라지 않지만 넘치면 되풀이한다.
    static func symbol(for index: Int) -> String {
        symbols[((index % symbols.count) + symbols.count) % symbols.count]
    }
}
