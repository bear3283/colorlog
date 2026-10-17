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
//  사용자 팔레트는 "user.<UUID>"다(`PaletteStore`).
//

import SwiftUI

nonisolated struct Palette: Identifiable, Equatable, Sendable {

    /// 팔레트가 어디서 왔는지.
    enum Source: Hashable, Sendable {
        case preset(ColorPalette)
        case user(UUID)

        var isUser: Bool {
            if case .user = self { true } else { false }
        }
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

    /// 프리셋. 사용자가 고친 색(`override`)이 있으면 그 색을 쓴다.
    ///
    /// 고친 색 중 원래 색과 같은 것은 원래 이름을 그대로 읽고, 바뀐 색은 순서로 부른다.
    /// 대체 아이콘은 원래 색으로 미리 그려 둔 그림이라, 색을 고친 프리셋은 기본 아이콘을 쓴다.
    init(preset: ColorPalette, override: [String]? = nil) {
        id = preset.rawValue
        source = .preset(preset)
        name = preset.displayName
        theme = preset.theme
        // 원래 색과 똑같이 덮어쓴 값은 고치지 않은 것으로 본다. 아이콘도 그대로.
        if let override, override != preset.swatches.map(\.hex) {
            let originals = Dictionary(preset.swatches.map { ($0.hex, $0.name) }, uniquingKeysWith: { first, _ in first })
            swatches = override.enumerated().map { index, hex in
                ColorSwatch(name: originals[hex] ?? "\(preset.displayName) 색 \(index + 1)", hex: hex)
            }
            alternateIconName = nil
        } else {
            swatches = preset.swatches
            alternateIconName = preset.alternateIconName
        }
    }

    /// 사용자가 만든 팔레트. 바탕은 흰 종이, 틴트는 첫 색.
    init(user: UserPalette) {
        id = user.paletteID
        source = .user(user.id)
        name = user.name
        // 사용자가 고른 색에는 이름이 없다. VoiceOver는 순서로 부른다.
        swatches = user.hexes.enumerated().map { index, hex in
            ColorSwatch(name: "\(user.name) 색 \(index + 1)", hex: hex)
        }
        theme = PaletteTheme(
            background:   Color(hex: "#FCFAF6", fallback: .white),
            surface:      Color(hex: "#FFFFFF", fallback: .white),
            ink:          Color(hex: "#2A2420", fallback: .black),
            inkSecondary: Color(hex: "#948A82", fallback: .gray),
            stroke:       Color(hex: "#ECE6E0", fallback: .gray),
            tint:         Color(hex: user.hexes.first ?? "#EF8089", fallback: .pink),
            colorScheme:  .light
        )
        alternateIconName = nil
    }

    static var `default`: Palette { resolve(ColorPalette.default.rawValue) }

    /// 설정에 늘어놓는 순서 그대로의 모든 팔레트. 프리셋 다음에 사용자 팔레트를 만든 순서로.
    static var all: [Palette] {
        let overrides = PaletteStore.presetOverrides
        return ColorPalette.allCases.map { Palette(preset: $0, override: overrides[$0.rawValue]) }
            + PaletteStore.userPalettes.map(Palette.init(user:))
    }

    /// 저장된 id로 팔레트를 찾는다. 모르는 id(지워졌거나 손상된 값)면 기본 팔레트.
    static func resolve(_ id: String) -> Palette {
        if let user = PaletteStore.userPalette(id: id) {
            return Palette(user: user)
        }
        // 예전 '나만의 팔레트'로 기록된 날은 그걸 옮겨 만든 사용자 팔레트로 읽는다.
        if id == PaletteStore.legacyCustomID,
           let migrated = ColorLogStore.defaults.string(forKey: PaletteStore.migratedCustomKey),
           let user = PaletteStore.userPalette(id: migrated) {
            return Palette(user: user)
        }
        let preset = ColorPalette(rawValue: id) ?? .default
        return Palette(preset: preset, override: PaletteStore.presetOverrides[preset.rawValue])
    }

    /// 지금 선택된 팔레트. 위젯 · 인텐트처럼 @AppStorage가 없는 곳에서 읽는다.
    static var current: Palette {
        PaletteStore.migrateLegacyCustomIfNeeded()
        return resolve(ColorLogStore.defaults.string(forKey: ColorLogStore.paletteKey) ?? ColorPalette.default.rawValue)
    }

    /// 사용자가 색을 고친 프리셋인지.
    var isModifiedPreset: Bool {
        guard case .preset(let preset) = source else { return false }
        return swatches.map(\.hex) != preset.swatches.map(\.hex)
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
