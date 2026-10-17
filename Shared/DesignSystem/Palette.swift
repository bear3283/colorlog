//
//  Palette.swift
//  colorlog (앱 · 위젯 공용)
//
//  화면과 기록이 쓰는 팔레트 한 벌.
//
//  `ColorPalette`는 앱에 실려 나가는 프리셋의 정의(이름 · 색 · 위젯 바탕 · 아이콘)이고,
//  `Palette`는 그걸 읽어 지금 쓸 수 있는 모양으로 푼 값이다. 둘을 나눈 건 프리셋이 아닌
//  팔레트(사용자가 만든 것)와 프리셋을 고친 값이 같은 자리에 들어오게 하기 위해서다.
//  화면은 팔레트가 어디서 왔는지 모른 채 `Palette`만 받는다.
//
//  저장되는 건 `id` 문자열 하나다. 프리셋은 `ColorPalette.rawValue` 그대로라
//  예전에 저장된 선택값과 기록의 `themePalette`가 바뀌지 않고 그대로 읽힌다.
//

import SwiftUI

nonisolated struct Palette: Identifiable, Equatable, Sendable {

    /// 팔레트가 어디서 왔는지.
    enum Source: Hashable, Sendable {
        case preset(ColorPalette)
    }

    /// 저장 키. 선택값(`ColorLogStore.paletteKey`)과 기록의 `themePalette`에 들어간다.
    let id: String
    let source: Source
    /// VoiceOver와 설정 카드 레이블에만 쓰는 이름.
    let name: String
    /// 고를 수 있는 색. 순서가 곧 화면의 순서다.
    let swatches: [ColorSwatch]
    /// 위젯이 쓰는 팔레트 자체의 테마. 앱 화면은 `appTheme(for:)`를 쓴다.
    let theme: PaletteTheme
    /// 이 팔레트에 맞춘 대체 앱 아이콘. nil이면 기본 아이콘.
    let alternateIconName: String?

    init(preset: ColorPalette) {
        id = preset.rawValue
        source = .preset(preset)
        name = preset.displayName
        swatches = preset.swatches
        theme = preset.theme
        alternateIconName = preset.alternateIconName
    }

    static var `default`: Palette { Palette(preset: .default) }

    /// 설정에 늘어놓는 순서 그대로의 모든 팔레트.
    static var all: [Palette] {
        ColorPalette.allCases.map(Palette.init(preset:))
    }

    /// 저장된 id로 팔레트를 찾는다. 모르는 id(지워졌거나 손상된 값)면 기본 팔레트.
    static func resolve(_ id: String) -> Palette {
        Palette(preset: ColorPalette(storedValue: id))
    }

    /// 지금 선택된 팔레트. 위젯 · 인텐트처럼 @AppStorage가 없는 곳에서 읽는다.
    static var current: Palette {
        resolve(ColorLogStore.defaults.string(forKey: ColorLogStore.paletteKey) ?? ColorPalette.default.rawValue)
    }

    /// HEX가 이 팔레트에 속하는 색인지. (저장된 기록의 색 이름을 되찾을 때)
    func swatch(for hex: String) -> ColorSwatch? {
        guard let normalized = HexColor.normalized(hex) else { return nil }
        return swatches.first { $0.hex.uppercased() == normalized }
    }

    /// 화면이 다시 그려져야 하는 차이만 비교한다. 테마는 색에서 나오므로 따로 보지 않는다.
    static func == (lhs: Palette, rhs: Palette) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.swatches == rhs.swatches
    }
}

// MARK: - 앱 화면의 테마

extension Palette {

    /// 앱 화면의 테마.
    ///
    /// 바탕은 팔레트와 상관없이 **흰 종이**(라이트) 또는 **먹빛**(다크)이고, 시스템의
    /// 화면 모드를 따른다. 팔레트마다 바탕을 물들였더니 칸마다 앉은 수채화 곰과 겹쳐
    /// 화면이 탁해졌다. 바탕을 비워 두면 곰과 그날의 색이 가장 또렷하다.
    /// 팔레트에서는 틴트(오늘의 빛 · 선택 표시)만 가져온다.
    ///
    /// 위젯은 홈 화면 위에 놓이는 작은 물건이라 팔레트 자체의 바탕(`theme`)을 쓴다.
    func appTheme(for scheme: ColorScheme) -> PaletteTheme {
        switch scheme {
        case .dark:
            PaletteTheme(
                background:   Color(hex: "#121214", fallback: .black),
                surface:      Color(hex: "#1E1E21", fallback: .black),
                ink:          Color(hex: "#F1EEE9", fallback: .white),
                inkSecondary: Color(hex: "#8F8B87", fallback: .gray),
                stroke:       Color(hex: "#2E2E32", fallback: .gray),
                tint:         theme.tint,
                colorScheme:  .dark
            )
        default:
            PaletteTheme(
                background:   Color(hex: "#FFFFFF", fallback: .white),
                surface:      Color(hex: "#F4F3F1", fallback: .white),
                ink:          Color(hex: "#221E1B", fallback: .black),
                inkSecondary: Color(hex: "#8E8984", fallback: .gray),
                stroke:       Color(hex: "#E7E4E0", fallback: .gray),
                tint:         theme.tint,
                colorScheme:  .light
            )
        }
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// 테마 토큰을 뷰 계층 전체에 흘려보낸다.
    /// 셀 하나하나에 테마를 인자로 넘기면 그리드가 배관 코드로 뒤덮이므로
    /// 루트에서 한 번만 주입하고 말단에서 꺼내 쓴다.
    @Entry var paletteTheme: PaletteTheme = ColorPalette.default.theme

    /// 팔레트 자체. 색을 기록할 때 `themePalette`로 함께 저장해야 하므로
    /// 파생된 토큰만으로는 부족하다.
    @Entry var colorPalette: Palette = .default
}

extension View {
    /// 하위 트리에 팔레트를 적용한다. 바탕은 시스템의 화면 모드를 따른다(`appTheme(for:)`).
    func paletteTheme(_ palette: Palette) -> some View {
        modifier(AppThemeModifier(palette: palette))
    }

    /// 프리셋을 바로 적용한다. 미리보기용 지름길.
    func paletteTheme(_ preset: ColorPalette) -> some View {
        paletteTheme(Palette(preset: preset))
    }
}

private struct AppThemeModifier: ViewModifier {
    let palette: Palette
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorPalette, palette)
            .environment(\.paletteTheme, palette.appTheme(for: colorScheme))
    }
}
