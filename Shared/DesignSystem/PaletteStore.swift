//
//  PaletteStore.swift
//  colorlog (앱 · 위젯 공용)
//
//  사용자가 만든 팔레트와, 사용자가 고친 프리셋의 색을 저장한다.
//
//  앱 · 위젯 · 인텐트가 함께 쓰는 App Group 설정에 JSON으로 둔다. 위젯과 인텐트는
//  모델 컨테이너 없이 팔레트를 바로 읽어야 하고, 양도 몇 KB를 넘지 않는다.
//  화면은 이 키들을 @AppStorage로 지켜보다가 값이 바뀌면 `Palette.all`을 다시 읽는다.
//
//  색을 바꾸거나 팔레트를 지워도 지난 기록은 그대로다. 기록은 고른 순간의 HEX를 저장한다.
//

import Foundation

/// 사용자가 만든 팔레트 한 벌.
nonisolated struct UserPalette: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    /// "나만의 팔레트 2"처럼 자동으로 붙는다. VoiceOver와 카드 레이블에만 쓰인다.
    var name: String
    /// 3~7개의 "#RRGGBB".
    var hexes: [String]
    var createdAt: Date

    /// 선택값 · 기록에 저장되는 `Palette.id`.
    var paletteID: String { PaletteStore.userPrefix + id.uuidString }
}

nonisolated enum PaletteStore {

    static let userPalettesKey = "colorlog.userPalettes"
    static let presetOverridesKey = "colorlog.presetOverrides"

    /// 사용자 팔레트 id의 머리. 프리셋 rawValue와 겹치지 않는다.
    static let userPrefix = "user."
    /// 팔레트 하나의 색 개수.
    static let colorRange = 3...7
    /// 만들 수 있는 사용자 팔레트 수.
    static let maxUserPalettes = 12

    private static var defaults: UserDefaults { ColorLogStore.defaults }

    // MARK: 읽기

    static var userPalettes: [UserPalette] {
        guard let data = defaults.data(forKey: userPalettesKey),
              let decoded = try? JSONDecoder().decode([UserPalette].self, from: data)
        else { return [] }
        // 손으로 고친 값이나 예전 형식이 섞여 있어도 화면이 깨지지 않게 한 번 거른다.
        return decoded.compactMap { palette in
            sanitize(palette.hexes).map { UserPalette(id: palette.id, name: palette.name, hexes: $0, createdAt: palette.createdAt) }
        }
    }

    /// 프리셋 rawValue → 사용자가 고친 색.
    static var presetOverrides: [String: [String]] {
        guard let data = defaults.data(forKey: presetOverridesKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return decoded.compactMapValues(sanitize)
    }

    static func userPalette(id: String) -> UserPalette? {
        guard id.hasPrefix(userPrefix), let uuid = UUID(uuidString: String(id.dropFirst(userPrefix.count))) else { return nil }
        return userPalettes.first { $0.id == uuid }
    }

    /// 정규형 HEX로 바꾸고, 개수가 맞지 않으면 nil.
    static func sanitize(_ hexes: [String]) -> [String]? {
        let normalized = hexes.compactMap(HexColor.normalized)
        guard normalized.count == hexes.count, colorRange.contains(normalized.count) else { return nil }
        return normalized
    }

    // MARK: 쓰기

    /// 새 사용자 팔레트. 빈 색에서 시작하면 막막하니 지금 팔레트의 색을 옮겨 담는다.
    /// 더 만들 수 없으면 nil.
    @discardableResult
    static func addPalette(copying hexes: [String]) -> UserPalette? {
        var palettes = userPalettes
        guard palettes.count < maxUserPalettes else { return nil }
        let start = sanitize(Array(hexes.prefix(colorRange.upperBound))) ?? ColorPalette.watercolor.swatches.map(\.hex)
        let palette = UserPalette(id: UUID(), name: nextName(after: palettes), hexes: start, createdAt: .now)
        palettes.append(palette)
        save(palettes)
        return palette
    }

    /// 팔레트의 색을 바꾼다. 사용자 팔레트면 그 팔레트를, 프리셋이면 덮어쓴 색을 고친다.
    /// 프리셋을 원래 색 그대로 되돌려 놓으면 덮어쓴 값은 지운다.
    static func setHexes(_ hexes: [String], for paletteID: String) {
        guard let clean = sanitize(hexes) else { return }
        if var palette = userPalette(id: paletteID) {
            palette.hexes = clean
            save(userPalettes.map { $0.id == palette.id ? palette : $0 })
        } else if let preset = ColorPalette(rawValue: paletteID) {
            var overrides = presetOverrides
            overrides[preset.rawValue] = clean == preset.swatches.map(\.hex) ? nil : clean
            save(overrides)
        }
    }

    static func deletePalette(id: UUID) {
        save(userPalettes.filter { $0.id != id })
    }

    /// 고친 프리셋을 원래 색으로.
    static func resetPreset(_ preset: ColorPalette) {
        var overrides = presetOverrides
        overrides[preset.rawValue] = nil
        save(overrides)
    }

    /// 비어 있는 가장 작은 번호. 2번을 지웠으면 다음 팔레트가 다시 2번이 된다.
    private static func nextName(after palettes: [UserPalette]) -> String {
        let used = Set(palettes.map(\.name))
        let number = (1...).first { !used.contains(name(number: $0)) } ?? palettes.count + 1
        return name(number: number)
    }

    private static func name(number: Int) -> String { "나만의 팔레트 \(number)" }

    private static func save(_ palettes: [UserPalette]) {
        defaults.set(try? JSONEncoder().encode(palettes), forKey: userPalettesKey)
    }

    private static func save(_ overrides: [String: [String]]) {
        defaults.set(try? JSONEncoder().encode(overrides), forKey: presetOverridesKey)
    }

    // MARK: 예전 '나만의 팔레트' 옮기기

    /// 1.1.0 개발 중에는 나만의 팔레트가 하나뿐이었다. 선택값 "custom"과 다섯 색 한 줄.
    static let legacyCustomID = "custom"
    private static let legacyHexesKey = "colorlog.customPalette"
    /// 옮겨 만든 사용자 팔레트의 id. 그때 기록된 날(`themePalette == "custom"`)이 이 팔레트로 읽힌다.
    static let migratedCustomKey = "colorlog.customPaletteMigratedTo"

    /// 예전 나만의 팔레트를 쓴 적이 있으면 사용자 팔레트 하나로 옮긴다. 한 번만 일어난다.
    /// 앱 · 위젯 어느 쪽이 먼저 열려도 되도록 `Palette.current`가 부른다.
    static func migrateLegacyCustomIfNeeded() {
        guard defaults.string(forKey: migratedCustomKey) == nil else { return }
        let selection = defaults.string(forKey: ColorLogStore.paletteKey)
        let legacy = defaults.string(forKey: legacyHexesKey)
            .flatMap { sanitize($0.split(separator: ",").map(String.init)) }

        // 손대지도 고르지도 않았다면 옮길 것이 없다.
        guard legacy != nil || selection == legacyCustomID else {
            defaults.set("", forKey: migratedCustomKey)
            return
        }
        guard let palette = addPalette(copying: legacy ?? ColorPalette.watercolor.swatches.map(\.hex)) else { return }
        defaults.set(palette.paletteID, forKey: migratedCustomKey)
        if selection == legacyCustomID {
            defaults.set(palette.paletteID, forKey: ColorLogStore.paletteKey)
        }
        defaults.removeObject(forKey: legacyHexesKey)
    }
}

// MARK: - 물감 섞기

/// 편집기의 두 손잡이(색상 · 진하기)가 만드는 색.
nonisolated enum PaintMix {

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
