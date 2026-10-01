//
//  SunlightBackground.swift
//  colorlog (앱 · 위젯 공용)
//
//  격자 뒤에서 하루가 흐르는 배경.
//
//  두 겹이다.
//   1) 하늘 — 배경색 자체가 시각을 따라 바뀐다. 새벽의 장밋빛, 아침의 옅은 금빛,
//      한낮의 맑은 청, 해 질 녘의 호박색, 밤의 남빛.
//   2) 해 — 그 위를 빛덩이 하나가 왼쪽 아래에서 떠올라 오른쪽 아래로 진다.
//      격자가 이미 '왼쪽에서 오른쪽으로' 시간을 담고 있으므로 같은 방향으로 움직인다.
//
//  해가 뜨고 지는 시각은 사용자가 정한 '물어보는 시각'의 처음과 끝을 쓴다.
//  08시에 첫 질문을 받는 사람에게는 그때가 하루의 시작이기 때문.
//
//  하늘은 팔레트 배경을 **덮지 않고 물들인다.** 하늘색을 그대로 깔면 다섯 팔레트가
//  같은 시각에 같은 화면이 되어 버린다. 밝은 팔레트는 밝은 하늘을, 어두운 팔레트는
//  어두운 하늘을 받아 자기 명도를 지킨다.
//

import SwiftUI

struct SunlightBackground: View {

    let theme: PaletteTheme

    var body: some View {
        // 1분마다 다시 그린다. 하늘은 그보다 빨리 변하지 않는다.
        TimelineView(.everyMinute) { context in
            SkyView(theme: theme, date: context.date)
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 1.2), value: theme.background)
    }
}

/// 특정 시각의 하늘 한 장. 위젯은 TimelineView 없이 이걸 직접 쓴다.
struct SkyView: View {

    let theme: PaletteTheme
    var date: Date = .now

    var body: some View {
        let sky = DaySky(date: date, theme: theme)
        let sun = SunPosition(date: date)

        GeometryReader { proxy in
            // 화면을 다 덮을 만큼 넓히면 '어디서 비치는지'가 사라진다.
            // 빛덩이가 화면의 절반쯤을 차지해야 위치가 읽힌다.
            let reach = max(proxy.size.width, proxy.size.height) * 0.58

            ZStack {
                LinearGradient(
                    colors: [sky.zenith, sky.horizon],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [sun.glow, .clear],
                    center: sun.point,
                    startRadius: 0,
                    endRadius: reach
                )
                .opacity(sun.strength * (theme.colorScheme == .dark ? 0.26 : 0.5))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

// MARK: - 하루의 시각표

/// 사용자의 하루가 언제 시작해 언제 끝나는지.
nonisolated struct DayHours {

    /// 해 뜨는 시각(시 단위, 0~24).
    let sunrise: Double
    /// 해 지는 시각.
    let sunset: Double

    init(reminders: [Reminder]? = nil) {
        let enabled = (reminders ?? Reminder.load()).filter(\.isEnabled)
        let hours = enabled.map { Double($0.hour) + Double($0.minute) / 60 }
        // 물어보는 시각이 하나도 없으면 흔한 하루(08~21시)를 가정한다.
        let start = hours.min() ?? 8
        let end = hours.max() ?? 21
        sunrise = start
        // 낮이 너무 짧거나 길면 새벽·한낮·저녁이 서로 겹치거나 밤이 사라진다.
        sunset = start + min(max(end - start, 4), 18)
    }

    static func hour(of date: Date, calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 12) + Double(components.minute ?? 0) / 60
    }
}

// MARK: - 하늘

/// 그 시각의 하늘색. 위(천정)와 아래(지평선) 두 색.
nonisolated struct DaySky {

    let zenith: Color
    let horizon: Color

    /// 하늘의 국면. 각 국면의 색은 **밝은 팔레트용과 어두운 팔레트용**이 따로 있다.
    /// 같은 장밋빛 새벽이라도 크림색 종이 위와 먹빛 위에서는 다른 명도여야 한다.
    enum Phase {
        case night, dawn, morning, noon, golden, dusk, twilight

        func tint(dark: Bool) -> (zenith: String, horizon: String) {
            switch (self, dark) {
            case (.night, false):    ("#B4B9DC", "#CFD2EA")
            case (.dawn, false):     ("#D9CFEA", "#F8C8B6")
            case (.morning, false):  ("#E2EDF7", "#FAE5C2")
            case (.noon, false):     ("#CFE4F8", "#EDF5FB")
            case (.golden, false):   ("#F0DFCF", "#F8C58E")
            case (.dusk, false):     ("#C9B9DE", "#EFAB9C")
            case (.twilight, false): ("#B0AFD6", "#D6BCD4")

            case (.night, true):     ("#04050D", "#0A0C1C")
            case (.dawn, true):      ("#211B3A", "#4A2633")
            case (.morning, true):   ("#15253A", "#382D20")
            case (.noon, true):      ("#163049", "#1D2B39")
            case (.golden, true):    ("#251E2E", "#4C2D19")
            case (.dusk, true):      ("#231840", "#4D2035")
            case (.twilight, true):  ("#12112C", "#221639")
            }
        }
    }

    /// 하늘이 팔레트 배경을 물들이는 정도.
    /// 1이면 팔레트가 사라지고, 너무 낮으면 시각이 읽히지 않는다.
    private static func strength(dark: Bool) -> Double { dark ? 0.62 : 0.68 }

    init(date: Date = .now, theme: PaletteTheme, hours: DayHours = DayHours()) {
        let dark = theme.colorScheme == .dark
        let (from, to, t) = Self.bracket(hour: DayHours.hour(of: date), hours: hours)

        func color(_ hex: String) -> Color { Color(hex: hex, fallback: theme.background) }
        let a = from.tint(dark: dark)
        let b = to.tint(dark: dark)
        let k = Self.strength(dark: dark)

        zenith = theme.background.mix(with: color(a.zenith).mix(with: color(b.zenith), by: t), by: k)
        horizon = theme.background.mix(with: color(a.horizon).mix(with: color(b.horizon), by: t), by: k)
    }

    /// 지금 시각이 어느 두 국면 사이에 있고, 그 사이 어디쯤인지.
    static func bracket(hour: Double, hours: DayHours) -> (Phase, Phase, Double) {
        let s = hours.sunrise
        let e = hours.sunset
        let keys: [(Phase, Double)] = [
            (.night, s - 1.5),
            (.dawn, s),
            (.morning, s + 1.5),
            (.noon, (s + e) / 2),
            (.golden, e - 1.5),
            (.dusk, e),
            (.twilight, e + 1),
            (.night, e + 2.5),
            (.night, s - 1.5 + 24),     // 한 바퀴 돌아 다음 날 새벽 전까지
        ]

        // 첫 국면(새벽 전 밤)보다 이르면 어제의 연장선이다.
        var h = hour
        if h < keys[0].1 { h += 24 }

        for (lower, upper) in zip(keys, keys.dropFirst()) where h < upper.1 {
            let span = max(upper.1 - lower.1, 0.001)
            let raw = min(max((h - lower.1) / span, 0), 1)
            // 국면 경계에서 색이 꺾이지 않도록 부드럽게 넘긴다.
            return (lower.0, upper.0, raw * raw * (3 - 2 * raw))
        }
        return (.night, .night, 0)
    }
}

// MARK: - 해의 위치

/// 하루 안에서 해가 어디쯤 떠 있는지.
nonisolated struct SunPosition {

    /// 화면 안에서의 좌표(0~1). 왼쪽 아래 → 머리 위 → 오른쪽 아래.
    let point: UnitPoint
    /// 지평선 위로 얼마나 올라왔는지(0~1). 정오에 1.
    let elevation: Double
    /// 빛의 세기(0~1). 해가 지면 0으로 잦아든다.
    let strength: Double

    /// 낮게 뜬 해는 붉고, 머리 위의 해는 차다.
    ///
    /// 실제 색온도도 그렇다 — 일출·일몰은 2000K 언저리의 주황, 한낮은 6000K의
    /// 푸른 백색. 한낮을 흰색으로 두면 밝은 하늘 위에서 빛이 통째로 사라진다.
    var glow: Color {
        Color(hex: "#FFB86B", fallback: .orange)
            .mix(with: Color(hex: "#CFE3F7", fallback: .blue), by: elevation)
    }

    init(date: Date = .now, hours: DayHours = DayHours()) {
        let sunrise = hours.sunrise
        let sunset = hours.sunset
        let now = DayHours.hour(of: date)

        // 해 뜨기 전·진 뒤에는 지평선 근처에 두고 빛만 거둔다.
        let span = max(sunset - sunrise, 1)
        let raw = (now - sunrise) / span
        let progress = min(max(raw, 0), 1)

        elevation = sin(progress * .pi)
        point = UnitPoint(x: progress, y: 0.88 - 0.78 * elevation)

        // 지평선 언저리에서 뚝 끊기지 않도록 한 시간에 걸쳐 잦아들게 한다.
        let fade = 1.0 / span
        strength = switch raw {
        case ..<(-fade): 0
        case ..<0:       (raw + fade) / fade
        case ...1:       1
        case ..<(1 + fade): 1 - (raw - 1) / fade
        default:         0
        }
    }
}

#if DEBUG
#Preview("하루의 하늘") {
    let hours = DayHours(reminders: Reminder.defaults())
    ScrollView(.horizontal) {
        HStack(spacing: 6) {
            ForEach([5.0, 7.0, 8.0, 9.5, 12.0, 15.0, 19.5, 21.0, 22.0, 23.5], id: \.self) { hour in
                let date = Calendar.current.date(
                    bySettingHour: Int(hour), minute: Int((hour - floor(hour)) * 60), second: 0, of: .now
                ) ?? .now
                VStack(spacing: 6) {
                    ForEach(ColorPalette.allCases) { palette in
                        let sky = DaySky(date: date, theme: palette.theme, hours: hours)
                        LinearGradient(colors: [sky.zenith, sky.horizon], startPoint: .top, endPoint: .bottom)
                            .frame(width: 56, height: 110)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
    }
}
#endif
