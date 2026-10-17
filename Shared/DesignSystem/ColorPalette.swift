//
//  ColorPalette.swift
//  colorlog
//
//  팔레트 프리셋 하나가 두 가지를 동시에 결정한다.
//   1) 앱 전체의 테마 토큰 (배경 / 잉크 / 테두리 / 틴트)
//   2) 사용자가 하루의 색을 고를 때 제시되는 스와치 목록
//  둘을 한 타입에 묶어 두어야 "테마를 바꾸면 세계관이 통째로 바뀌는" 경험이 성립한다.
//

import SwiftUI

// MARK: - Swatch

/// 사용자가 고를 수 있는 색 한 알. 이름은 시적으로, 값은 HEX로.
nonisolated struct ColorSwatch: Identifiable, Hashable, Sendable {
    let name: String
    let hex: String

    var id: String { hex }
    var color: Color { Color(hex: hex, fallback: .gray) }
}

// MARK: - Theme Tokens

/// 팔레트가 앱 전역에 주입하는 색 토큰 묶음.
nonisolated struct PaletteTheme: Sendable {
    /// 앱 최하단 배경. 빈 칸의 글래스모피즘은 이 색이 비쳐 보이는 것.
    let background: Color
    /// 시트·카드 등 배경 위에 뜨는 표면.
    let surface: Color
    /// 본문 텍스트(명조체)의 먹빛.
    let ink: Color
    /// 날짜 캡션 등 보조 텍스트.
    let inkSecondary: Color
    /// 미래의 빈 칸에 두르는 아주 얇은 테두리.
    let stroke: Color
    /// 강조/선택 상태 틴트.
    let tint: Color
    /// 이 팔레트가 전제하는 명암 모드.
    let colorScheme: ColorScheme

    /// 배경에 아주 옅은 깊이를 주기 위한 그라데이션. (평평한 단색을 피한다)
    ///
    /// 반투명 색을 겹치면 그 아래의 검정이 비쳐 다크 테마가 회색빛으로 탁해진다.
    /// 반드시 불투명한 두 색 사이를 지나가야 한다.
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Palette

/// 저장되는 값은 `rawValue`(안정적 ID)다. 한글 표기명은 절대 저장하지 않는다.
nonisolated enum ColorPalette: String, CaseIterable, Identifiable, Codable, Sendable {
    case pantone       = "pantone"
    /// 칼라베어 앱 아이콘(수채화 곰 원화)에 번진 다섯 색.
    case watercolor    = "watercolor"
    case complementary = "complementary"
    case analogous     = "analogous"
    case spring        = "spring"
    case driedFlower   = "driedFlower"
    case triadic       = "triadic"
    case monochrome    = "monochrome"
    case cloud         = "cloud"
    case jewel         = "jewel"
    /// 사용자가 직접 고른 다섯 색(`CustomPalette`). 늘 목록의 맨 끝.
    case custom        = "custom"

    static let `default`: ColorPalette = .pantone

    var id: String { rawValue }

    /// 알 수 없는 저장값(구버전·손상)이 와도 앱이 멈추지 않도록 하는 진입점.
    init(storedValue: String) {
        self = ColorPalette(rawValue: storedValue) ?? .default
    }

    // MARK: 표기

    /// 설정 화면에서만 쓰인다. 캔버스에는 어떤 글자도 올리지 않는다.
    var displayName: String {
        switch self {
        case .pantone:       "클래식"
        case .watercolor:    "수채 곰"
        case .complementary: "보색"
        case .analogous:     "유사색"
        case .spring:        "봄"
        case .driedFlower:   "말린 꽃"
        case .triadic:       "삼색"
        case .monochrome:    "단색"
        case .cloud:         "구름"
        case .jewel:         "보석"
        case .custom:        "나만의 팔레트"
        }
    }

    // MARK: 테마 토큰

    var theme: PaletteTheme {
        switch self {
        case .custom:
            // 바탕은 흰 종이. 틴트는 사용자가 고른 첫 색.
            PaletteTheme(
                background:   Color(hex: "#FCFAF6", fallback: .white),
                surface:      Color(hex: "#FFFFFF", fallback: .white),
                ink:          Color(hex: "#2A2420", fallback: .black),
                inkSecondary: Color(hex: "#948A82", fallback: .gray),
                stroke:       Color(hex: "#ECE6E0", fallback: .gray),
                tint:         Color(hex: CustomPalette.hexes[0], fallback: .pink),
                colorScheme: .light
            )
        case .watercolor:
            // 원화의 종이처럼 살짝 따뜻한 흰빛. 틴트는 곰 볼에 번진 분홍.
            PaletteTheme(
                background:   Color(hex: "#FCFAF6", fallback: .white),
                surface:      Color(hex: "#FFFFFF", fallback: .white),
                ink:          Color(hex: "#3B2A22", fallback: .black),
                inkSecondary: Color(hex: "#9A8E86", fallback: .gray),
                stroke:       Color(hex: "#ECE6E0", fallback: .gray),
                tint:         Color(hex: "#EF8089", fallback: .pink),
                colorScheme: .light
            )
        case .pantone:
            PaletteTheme(
                background:   Color(hex: "#FAF7F4", fallback: .white),
                surface:      Color(hex: "#FFFFFF", fallback: .white),
                ink:          Color(hex: "#241F1C", fallback: .black),
                inkSecondary: Color(hex: "#8C807A", fallback: .gray),
                stroke:       Color(hex: "#E6DED8", fallback: .gray),
                tint:         Color(hex: "#BB2649", fallback: .pink),
                colorScheme: .light
            )
        case .complementary:
            PaletteTheme(
                background:   Color(hex: "#F7F9FB", fallback: .white),
                surface:      Color(hex: "#FFFFFF", fallback: .white),
                ink:          Color(hex: "#10202E", fallback: .black),
                inkSecondary: Color(hex: "#7E8D99", fallback: .gray),
                stroke:       Color(hex: "#DDE5EC", fallback: .gray),
                tint:         Color(hex: "#FF7A29", fallback: .orange),
                colorScheme: .light
            )
        case .analogous:
            PaletteTheme(
                background:   Color(hex: "#F1F6F0", fallback: .white),
                surface:      Color(hex: "#FFFFFF", fallback: .white),
                ink:          Color(hex: "#16231C", fallback: .black),
                inkSecondary: Color(hex: "#7C8C80", fallback: .gray),
                stroke:       Color(hex: "#DCE6DB", fallback: .gray),
                tint:         Color(hex: "#009B8F", fallback: .teal),
                colorScheme: .light
            )
        case .spring:
            // 다섯 색이 모두 채도가 높아, 바탕은 거의 흰빛에 가깝게 두고
            // 연두 쪽으로 아주 살짝만 기울였다. 따뜻한 크림색이면 오렌지·핑크가 묻힌다.
            PaletteTheme(
                background:   Color(hex: "#F6F8F2", fallback: .white),
                surface:      Color(hex: "#FFFFFF", fallback: .white),
                ink:          Color(hex: "#221B26", fallback: .black),
                inkSecondary: Color(hex: "#8A8391", fallback: .gray),
                stroke:       Color(hex: "#E3E6DC", fallback: .gray),
                // 다섯 중 가장 짙은 색. 밝은 바탕 위에서 오늘 칸 테두리가 또렷해야 한다.
                tint:         Color(hex: "#B23F8A", fallback: .purple),
                colorScheme: .light
            )
        case .driedFlower:
            // 견본 사진의 바탕이던 가드니아(#EEE9E0)를 한 톤 밝혀 깔았다.
            // 다섯 색이 모두 회색기를 머금은 중간 명도라, 흰 바탕보다 이쪽에서 덜 탁해 보인다.
            PaletteTheme(
                background:   Color(hex: "#F3EFE8", fallback: .white),
                surface:      Color(hex: "#FFFFFF", fallback: .white),
                ink:          Color(hex: "#2A2420", fallback: .black),
                inkSecondary: Color(hex: "#8E857C", fallback: .gray),
                stroke:       Color(hex: "#E2DBD0", fallback: .gray),
                tint:         Color(hex: "#9C7867", fallback: .brown),
                colorScheme: .light
            )
        case .triadic:
            PaletteTheme(
                background:   Color(hex: "#121216", fallback: .black),
                surface:      Color(hex: "#1C1C22", fallback: .black),
                ink:          Color(hex: "#F0F0F4", fallback: .white),
                inkSecondary: Color(hex: "#8A8A96", fallback: .gray),
                stroke:       Color(hex: "#2A2A33", fallback: .gray),
                tint:         Color(hex: "#F5C518", fallback: .yellow),
                colorScheme: .dark
            )
        case .monochrome:
            PaletteTheme(
                background:   Color(hex: "#0C0D1A", fallback: .black),
                surface:      Color(hex: "#15172A", fallback: .black),
                ink:          Color(hex: "#E4E6F5", fallback: .white),
                inkSecondary: Color(hex: "#7A7F9E", fallback: .gray),
                stroke:       Color(hex: "#232640", fallback: .gray),
                tint:         Color(hex: "#6B73C4", fallback: .indigo),
                colorScheme: .dark
            )
        case .cloud:
            // 다섯 색이 전부 밝은 파스텔이다. 밝은 바탕에 두면 칠한 칸과
            // 빈 칸이 구분되지 않아, 바탕을 어둡게 깔고 색이 빛처럼 떠오르게 했다.
            PaletteTheme(
                background:   Color(hex: "#1C1E25", fallback: .black),
                surface:      Color(hex: "#262932", fallback: .black),
                ink:          Color(hex: "#EEECF2", fallback: .white),
                inkSecondary: Color(hex: "#8D8F9B", fallback: .gray),
                stroke:       Color(hex: "#333643", fallback: .gray),
                tint:         Color(hex: "#F5E8B6", fallback: .yellow),
                colorScheme: .dark
            )
        case .jewel:
            // 클래식 블루를 중심에 둔 견본. 바탕은 그 파랑을 밤처럼 가라앉힌 색,
            // 글자는 견본의 카놀리 크림.
            PaletteTheme(
                background:   Color(hex: "#11141F", fallback: .black),
                surface:      Color(hex: "#1A1E2C", fallback: .black),
                ink:          Color(hex: "#EFEEE6", fallback: .white),
                inkSecondary: Color(hex: "#8A8C99", fallback: .gray),
                stroke:       Color(hex: "#272B3B", fallback: .gray),
                tint:         Color(hex: "#DDDEA1", fallback: .yellow),
                colorScheme: .dark
            )
        }
    }

    // MARK: 기록용 스와치

    /// 하루의 분위기를 고르는 색 다섯.
    ///
    /// 팔레트마다 **배색 규칙 자체가 다르다.** 색상만 갈아 끼우면 넷 다
    /// '빨강-노랑-청록-파랑-무채'라는 같은 구조의 변주가 되어, 배경색만 다른
    /// 팔레트처럼 보인다. 규칙이 달라야 캔버스에 남는 그림의 성격이 달라진다.
    ///
    /// 이름은 화면에 뜨지 않는다 — VoiceOver 레이블로만 쓰인다.
    var swatches: [ColorSwatch] {
        switch self {
        case .custom:
            // 색 이름은 VoiceOver만 읽는다. 사용자가 고른 색에는 이름이 없으니 순서로 부른다.
            CustomPalette.hexes.enumerated().map { index, hex in
                ColorSwatch(name: "나만의 색 \(index + 1)", hex: hex)
            }
        case .watercolor:
            // 앱 아이콘 원화에서 색상(hue)별로 묶어 읽은 다섯 색. 원화의 색은 이미 물에 풀린
            // 파스텔이라 그대로 쓰면 곰을 칠할 때 거의 보이지 않는다. 색상은 그대로 두고
            // 물감이 고인 정도로 진하게 잡았다 — 곰 위에 번지면 원화와 비슷한 파스텔이 된다.
            // 원화의 연두는 노랑 · 민트와 겹쳐 뺐다.
            [
                ColorSwatch(name: "분홍",   hex: "#EF8089"),
                ColorSwatch(name: "하늘",   hex: "#6CB2E5"),
                ColorSwatch(name: "노랑",   hex: "#F6CD51"),
                ColorSwatch(name: "라벤더", hex: "#B98CD9"),
                ColorSwatch(name: "민트",   hex: "#64C4A1"),
            ]
        case .pantone:
            // 해마다 따로 고른 '올해의 색' 계열에서 출발했다. 서로 조화를 전제하지 않는다.
            //
            // ⚠️ 화면·VoiceOver에 쓰이는 이름(팔레트 이름 포함)에는 상표가 된 색 이름을
            // 쓰지 않는다. 1.0 심사에서 제3자 보호 자료 여부를 물어 와, 이 팔레트와
            // 말린 꽃·구름·보석의 색 이름을 전부 일반 색 이름으로 바꿨다.
            // 다섯 색이 각자 다른 방향을 보는, 가장 넓은 팔레트.
            //
            // 베리 페리(2022) 대신 그리너리(2017)를 넣었다. 베리 페리와 클래식 블루가
            // 같은 청보라 계열이라 한 칸에 나란히 놓이면 경계가 뭉개졌고(OKLab ΔE 0.146),
            // 다섯 중 초록이 하나도 없어 캔버스가 붉은 쪽으로만 기울었다.
            [
                ColorSwatch(name: "마젠타",   hex: "#BB2649"),
                ColorSwatch(name: "피치",     hex: "#FFBE98"),
                ColorSwatch(name: "연두",     hex: "#88B04B"),
                ColorSwatch(name: "코발트",   hex: "#0F4C81"),
                ColorSwatch(name: "모카",     hex: "#A47864"),
            ]
        case .complementary:
            // 색상환의 정반대 두 축(주황 ↔ 파랑)만 쓴다. 고를 때마다
            // '따뜻한가 차가운가' 하나만 묻게 되는 팔레트.
            [
                ColorSwatch(name: "밝은 주황",   hex: "#FF7A29"),
                ColorSwatch(name: "진한 주황",   hex: "#C9450C"),
                ColorSwatch(name: "연한 파랑",   hex: "#8FC5E8"),
                ColorSwatch(name: "파랑",        hex: "#1D6FB8"),
                ColorSwatch(name: "짙은 남색",   hex: "#0B2E4F"),
            ]
        case .analogous:
            // 색상환에서 붙어 있는 구간(연두 → 청록 → 남색)만. 대비가 없어
            // 캔버스 전체가 하나의 풍경처럼 이어진다.
            //
            // 색상이 가까운 만큼 **명도로 갈라야** 한 칸 안의 경계가 읽힌다.
            // OKLCH 명도를 0.88 → 0.75 → 0.62 → 0.50 → 0.36으로 고르게 벌렸다.
            // (이전 값은 초록·청록이 0.72·0.65로 붙어 나란히 놓이면 한 덩어리로 보였다)
            [
                ColorSwatch(name: "연두",   hex: "#CEE654"),
                ColorSwatch(name: "초록",   hex: "#63C776"),
                ColorSwatch(name: "청록",   hex: "#009B8F"),
                ColorSwatch(name: "파랑",   hex: "#0E6A9B"),
                ColorSwatch(name: "남색",   hex: "#223B6C"),
            ]
        case .spring:
            // 봄의 다섯. 연두·청록·주황·자주·분홍 — 색상환을 거의 한 바퀴 돈다.
            // 사용자가 가져온 견본 이미지에서 색을 그대로 읽었다.
            // 주황과 분홍은 명도가 비슷하지만(L 0.74·0.72) 색상이 60° 떨어져
            // 한 칸에 나란히 놓여도 경계가 읽힌다.
            [
                ColorSwatch(name: "라임",   hex: "#ACCD4A"),
                ColorSwatch(name: "청록",   hex: "#069792"),
                ColorSwatch(name: "오렌지", hex: "#EE922D"),
                ColorSwatch(name: "자주",   hex: "#B23F8A"),
                ColorSwatch(name: "분홍",   hex: "#EE7B9C"),
            ]
        case .driedFlower:
            // 말린 꽃과 흙빛. 사용자가 가져온 견본 이미지에서 색을 그대로 읽었다.
            // 견본 여덟 중 코블스톤(회갈색)·윌로(올리브)는 모카·텐드릴과 붙어 빠졌고,
            // 가드니아는 빈 칸과 구분되지 않아 바탕으로 돌렸다.
            [
                ColorSwatch(name: "세이지",   hex: "#8C9E6E"),
                ColorSwatch(name: "물빛 파랑", hex: "#7890C4"),
                ColorSwatch(name: "연보라",   hex: "#A393B6"),
                ColorSwatch(name: "장밋빛 베이지", hex: "#C99E9A"),
                ColorSwatch(name: "갈색",     hex: "#9C7867"),
            ]
        case .triadic:
            // 색상환 120° 간격의 빨강·노랑·파랑에 명도 양끝을 더했다.
            // 검정 배경 위라 세 원색이 서로 물러서지 않는다.
            [
                ColorSwatch(name: "빨강",   hex: "#E8302A"),
                ColorSwatch(name: "노랑",   hex: "#F5C518"),
                ColorSwatch(name: "파랑",   hex: "#1B5FCC"),
                ColorSwatch(name: "흰빛",   hex: "#E9E9EE"),
                ColorSwatch(name: "잿빛",   hex: "#5A5A6E"),
            ]
        case .monochrome:
            // 색상 하나(인디고)의 명도만 다섯 단계. 무엇을 골라도 색이 아니라
            // **무게**를 고르게 되는 팔레트.
            [
                ColorSwatch(name: "가장 옅게", hex: "#DDE0F5"),
                ColorSwatch(name: "옅게",      hex: "#A3A9DE"),
                ColorSwatch(name: "중간",      hex: "#6B73C4"),
                ColorSwatch(name: "짙게",      hex: "#3F4691"),
                ColorSwatch(name: "가장 짙게", hex: "#1E2252"),
            ]
        case .cloud:
            // 구름 낀 아침의 파스텔. 견본 이미지의 색에서 출발했다.
            //
            // 견본 그대로는 다섯 색의 명도가 0.85~0.94에 몰려, 한 칸에 두세 색이
            // 놓이면 하나로 뭉개졌다(가장 가까운 짝 OKLab ΔE 0.037).
            // 색상은 그대로 두고 명도를 0.93 → 0.68로 벌리고 채도를 조금 올렸다(ΔE 0.076).
            // 무채색인 님버스 클라우드·클라우드 댄서는 뺐다.
            // 다섯째 자리는 처음엔 오키드 틴트였는데 사용자 요청으로 레인드롭스 온
            // 로지스로 바꿨다. 같은 명도(0.68)에 두어 사다리는 그대로다.
            [
                ColorSwatch(name: "레몬",     hex: "#F5E8B6"),
                ColorSwatch(name: "하늘",     hex: "#BFD4E7"),
                ColorSwatch(name: "살구",     hex: "#D4B7A6"),
                ColorSwatch(name: "쑥색",     hex: "#A5B095"),
                ColorSwatch(name: "장미",     hex: "#AB9098"),
            ]
        case .jewel:
            // 견본의 '색 조화' 띠 세 줄에서 함께 쓰인 색들. 금속 질감 칩 대신
            // 평평한 띠에서 색을 읽었다. 무채색인 오팔 그레이·카놀리 크림, 그리고
            // 어두운 바탕에서 가라앉는 글리스닝 그레이프는 뺐다.
            [
                ColorSwatch(name: "남청",     hex: "#3B5287"),
                ColorSwatch(name: "옥빛",     hex: "#DDDEA1"),
                ColorSwatch(name: "초록",     hex: "#548E58"),
                ColorSwatch(name: "체리",     hex: "#A33333"),
                ColorSwatch(name: "황동",     hex: "#A27256"),
            ]
        }
    }

    /// 설정 화면에서 팔레트를 미리 보여줄 때 쓰는 대표 4색.
    var previewColors: [Color] {
        swatches.prefix(4).map(\.color)
    }

    /// 이 팔레트에 대응하는 대체 앱 아이콘 이름. 기본 팔레트는 기본 아이콘(nil)을 쓴다.
    /// 값은 Assets.xcassets의 appiconset 이름과 정확히 일치해야 한다.
    var alternateIconName: String? {
        switch self {
        case .pantone:       nil
        // 기본 아이콘이 바로 이 팔레트의 원화 곰이다.
        case .watercolor:    nil
        case .custom:        nil
        case .complementary: "AppIcon-Complementary"
        case .analogous:     "AppIcon-Analogous"
        // 전용 아이콘 에셋이 아직 없다. 생기면 이름을 넣는다.
        case .spring, .driedFlower, .cloud, .jewel: nil
        case .triadic:       "AppIcon-Triadic"
        case .monochrome:    "AppIcon-Monochrome"
        }
    }

    /// HEX가 이 팔레트에 속하는 색인지. (저장된 로그의 이름 역추적용)
    func swatch(for hex: String) -> ColorSwatch? {
        guard let normalized = HexColor.normalized(hex) else { return nil }
        return swatches.first { $0.hex.uppercased() == normalized }
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
    @Entry var colorPalette: ColorPalette = .default
}

extension ColorPalette {

    /// 앱 화면의 테마.
    ///
    /// 바탕은 팔레트와 상관없이 **흰 종이**(라이트) 또는 **먹빛**(다크)이고, 시스템의
    /// 화면 모드를 따른다. 팔레트마다 바탕을 물들였더니 칸마다 앉은 수채화 곰과 겹쳐
    /// 화면이 탁해졌다. 바탕을 비워 두면 곰과 그날의 색이 가장 또렷하다.
    /// 팔레트에서는 틴트(오늘의 빛 · 선택 표시)만 가져온다.
    ///
    /// 위젯은 홈 화면 위에 놓이는 작은 물건이라 지금처럼 팔레트 자체의 바탕(`theme`)을 쓴다.
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

extension View {
    /// 하위 트리에 팔레트를 적용한다. 바탕은 시스템의 화면 모드를 따른다(`appTheme(for:)`).
    func paletteTheme(_ palette: ColorPalette) -> some View {
        modifier(AppThemeModifier(palette: palette))
    }
}

private struct AppThemeModifier: ViewModifier {
    let palette: ColorPalette
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorPalette, palette)
            .environment(\.paletteTheme, palette.appTheme(for: colorScheme))
    }
}
