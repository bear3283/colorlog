//
//  TodayColorView.swift
//  colorlog (앱 · 위젯 공용)
//
//  홈 화면 위젯의 얼굴. 위젯은 **오늘이라는 칸 하나를 크게 키운 것**이다.
//
//  얼굴은 둘뿐이고, 둘 다 글자가 없다. 두 얼굴 모두 오늘의 곰이 주인공이다.
//
//   · 칠해진 얼굴 — 물어볼 차례가 아닐 때. 오늘 고른 색으로 칠한 곰이 앉아 있다.
//     앱 격자의 오늘 칸과 같은 동작 · 같은 번짐이다.
//     아직 아무것도 고르지 않았으면 앱 아이콘의 곰(`logoBear`)이 서 있다.
//
//   · 고르는 얼굴 — 물어보는 시각이 되면 하늘이 깔리고, 위젯 가득 선 곰 위로
//     색 다섯이 겹쳐 둘러선다. 첫 색을 기다릴 땐 앱 아이콘의 곰이다.
//     앱의 원형 팔레트와 같은 모양이라 '칸을 누르면 색이 둘러선다'는 한 가지
//     동작으로 두 표면이 이어진다.
//
//  두 얼굴은 바탕부터 다르다. 칠해진 얼굴은 팔레트 바탕 위의 곰이고,
//  고르는 얼굴은 하늘 위에 색 알들이 떠 있다. 그래서 '지금 고를 차례'라는 걸
//  문장 없이도 알 수 있다.
//
//  홈 화면 틴트 · 투명 모드(iOS 26)와 스탠바이 밤 모드에서는 시스템이 위젯을 한 가지 색으로
//  다시 칠해 곰의 물감도, 색 알의 색도 사라진다. 그때는 단색 얼굴로 바꾼다(`isMonochrome`).
//   · 칠해진 얼굴 — 곰의 연필 선 + 세 자리의 시간대 기호와 모양(`TodaySlotMarks`) + "2/3"
//   · 고르는 얼굴 — 가운데에 물어보는 시간대 기호와 이름("점심"), 둘러선 알마다 팔레트 순서의
//     모양(●▲■◆★…). 색을 볼 수 없어도 '몇 번째 색'을 골라 기록할 수 있다.
//

import AppIntents
import SwiftUI
import WidgetKit

struct TodayColorView: View {

    /// 그리는 시각. 고르는 얼굴의 하늘이 이 시각을 따른다.
    let date: Date
    /// 오늘의 자리별 색. ""는 빈 자리.
    let colors: [String]
    /// 지금 물어보는 자리. nil이면 칠해진 얼굴.
    let target: DailyColorLog.Slot?
    var palette: Palette = .default
    /// 오늘 기록에 저장된 곰의 동작. 앱에서 바꾼 동작이 위젯에도 그대로 앉는다.
    var pose: BearPose? = nil
    /// 단색 얼굴을 강제로 그린다. 미리보기 · 스크린샷용. 위젯에서는 렌더링 모드가 정한다.
    var forcesMonochrome = false

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// 색이 사라지는 렌더링 모드인가. 틴트(accented) · 투명/잠금(vibrant)은 단색으로 다시 칠해진다.
    private var isMonochrome: Bool { forcesMonochrome || renderingMode != .fullColor }

    /// 지금 물어볼 자리.
    ///
    /// **가장 최근에 물어본 자리가 비어 있을 때만** 묻는다. 그보다 앞서 놓친 자리는
    /// 위젯이 다시 조르지 않는다 — 13시에 위젯을 봤는데 아침 색을 고르라고 하면
    /// '지금, 어떤 색인가'라는 질문이 어긋난다. 놓친 자리는 앱에서 그 자리를 골라 채운다.
    static func target(slotColors: [String], due: [DailyColorLog.Slot]) -> DailyColorLog.Slot? {
        guard let latest = due.last else { return nil }
        let hex = slotColors.indices.contains(latest.index) ? slotColors[latest.index] : ""
        return hex.isEmpty ? latest : nil
    }

    private var theme: PaletteTheme { palette.theme }
    private var day: Date { Calendar.current.startOfDay(for: date) }

    var body: some View {
        GeometryReader { proxy in
            switch (target, isMonochrome) {
            case (let target?, false): chooser(in: proxy.size, target: target)
            case (let target?, true): monochromeChooser(in: proxy.size, target: target)
            case (nil, false): paintedFace
            case (nil, true): monochromePaintedFace(in: proxy.size)
            }
        }
        .environment(\.paletteTheme, theme)
        .environment(\.colorPalette, palette)
    }

    // MARK: 칠해진 얼굴

    /// 자리 순서의 색. nil은 빈 자리.
    private var pigments: [HexColor.Components?] {
        colors
            .prefix(DailyColorLog.maxColorsPerDay)
            .map { $0.isEmpty ? nil : HexColor.components(from: $0) }
    }

    private var hasColors: Bool { pigments.contains { $0 != nil } }

    /// 오늘의 곰. 앱 격자의 오늘 칸과 같은 동작 · 같은 번짐이다.
    /// 위젯은 한 번 그려 보관되는 정지 화면이라 번지는 애니메이션 없이 다 칠한 채로 그린다.
    private func todayBear(_ bear: DayBear) -> some View {
        WatercolorBearView(
            day: bear,
            colors: colors.filter { !$0.isEmpty }.map { Color(hex: $0, fallback: .gray) },
            seed: day.colorSeed,
            bloomsOnAppear: false)
    }

    private var filledCount: Int { pigments.count { $0 != nil } }

    /// 아직 아무 색도 고르지 않은 날의 곰. 앱 아이콘과 같은 곰(서 있는 곰, 같은 번짐)을
    /// 팔레트의 색으로 칠한다. 색이 없다고 자거나 시무룩한 곰을 두면 위젯이 처져 보인다.
    private var logoBear: some View {
        WatercolorBearView(
            moodColors: palette.swatches.map(\.color),
            pose: .standing,
            seed: WatercolorBearView.logoSeed,
            bloomsOnAppear: false)
    }

    /// 오늘 칠한 색이 있으면 그 색의 곰, 없으면 앱 아이콘의 곰.
    @ViewBuilder
    private var currentBear: some View {
        if hasColors {
            todayBear(DayBear(date: day, filledCount: filledCount, relation: .today, storedPose: pose))
        } else {
            logoBear
        }
    }

    /// 칠해진 얼굴. 물어볼 차례가 아닐 때의 위젯.
    ///
    /// 아직 아무것도 고르지 않았으면 앱 아이콘의 곰. 고른 색이 있으면 그 색으로 칠한 오늘의 곰.
    private var paintedFace: some View {
        ZStack {
            theme.background
            currentBear
                .padding(8)
        }
        .accessibilityElement()
        .accessibilityLabel(hasColors ? String(localized: "오늘 색 \(filledCount)개 기록됨") : String(localized: "오늘 아직 기록 없음"))
    }

    // MARK: 단색 얼굴

    private var slots: TodaySlots { TodaySlots(colors: colors, target: target, palette: palette) }

    /// 오늘의 곰 자세(칠해진 날은 그날 자세, 아직이면 앱 아이콘처럼 선 곰).
    private var currentPose: BearPose {
        hasColors
            ? DayBear(date: day, filledCount: filledCount, relation: .today, storedPose: pose).pose
            : .standing
    }

    /// 곰의 연필 선만. 갈색 선은 밝기가 낮아 투명 · 잠금 모드(밝기 → 불투명도)에서 사라지므로
    /// 밝게 뒤집어 흰 선으로 둔다. 틴트 모드에서는 그 선이 틴트 색이 된다.
    private var monochromeBear: some View {
        currentPose.art(.ink)
            .grayscale(1)
            .colorInvert()
            .brightness(0.15)
            .aspectRatio(1, contentMode: .fit)
    }

    private func monochromePaintedFace(in size: CGSize) -> some View {
        let isWide = size.width > size.height * 1.4
        let short = min(size.width, size.height)
        let markSize = min(max(short * 0.11, 13), 22)
        let progress = Text(verbatim: slots.progressText)
            .font(.system(size: markSize * 1.15, weight: .bold, design: .rounded))
            .monospacedDigit()
            .widgetAccentable()
        let marks = TodaySlotMarks(slots: slots, symbolSize: markSize, spacing: markSize * 0.9)

        return Group {
            if isWide {
                HStack(spacing: short * 0.12) {
                    monochromeBear.frame(height: size.height * 0.78)
                    VStack(alignment: .leading, spacing: markSize * 0.6) {
                        Text(slots.headline)
                            .font(.system(size: markSize * 0.95, weight: .semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        marks
                        progress
                    }
                }
            } else {
                VStack(spacing: markSize * 0.45) {
                    monochromeBear.frame(maxHeight: size.height * 0.56)
                    marks
                    progress
                }
                .padding(.vertical, short * 0.06)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slots.accessibilityText)
    }

    /// 색 알은 단색이 되어 서로 구별되지 않으므로, 알마다 팔레트 순서의 모양을 얹는다.
    /// 가운데에는 곰 대신 지금 물어보는 시간대 — 기호와 이름 — 를 둔다.
    private func monochromeChooser(in size: CGSize, target: DailyColorLog.Slot) -> some View {
        let short = min(size.width, size.height)
        let orb = min(short * 0.24, 54)
        let inset = short * 0.075
        let ry = size.height / 2 - orb / 2 - inset
        let rx = min(size.width / 2 - orb / 2 - inset, ry * 1.8)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return ZStack {
            VStack(spacing: short * 0.02) {
                Image(systemName: target.symbolName)
                    .font(.system(size: short * 0.16, weight: .semibold))
                    .widgetAccentable()
                Text(target.displayName)
                    .font(.system(size: short * 0.1, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: short * 0.42)
            .position(center)
            .accessibilityHidden(true)

            ForEach(Array(palette.swatches.enumerated()), id: \.element.id) { index, swatch in
                let angle = -Double.pi / 2 + Double(index) * 2 * .pi / Double(palette.swatches.count)

                Button(intent: RecordColorIntent(hex: swatch.hex, slot: target)) {
                    ZStack {
                        Circle().fill(.white.opacity(0.14))
                        Circle().strokeBorder(.white.opacity(0.85), lineWidth: max(1.5, orb * 0.05))
                        Image(systemName: SwatchMark.symbol(for: index))
                            .font(.system(size: orb * 0.4, weight: .bold))
                            .widgetAccentable()
                    }
                }
                .buttonStyle(.plain)
                .frame(width: orb, height: orb)
                .position(x: center.x + cos(angle) * rx, y: center.y + sin(angle) * ry)
                .accessibilityLabel("\(target.displayName)에 \(swatch.name) 기록")
            }
        }
    }

    // MARK: 고르는 얼굴

    private func chooser(in size: CGSize, target: DailyColorLog.Slot) -> some View {
        let short = min(size.width, size.height)
        let orb = min(short * 0.24, 54)
        let inset = short * 0.075

        // 정사각형이면 원, 가로로 긴 위젯이면 타원으로 둘러선다.
        // 타원을 가로 끝까지 펴면 색들이 흩어져 '칸에서 나온 것'으로 읽히지 않는다.
        let ry = size.height / 2 - orb / 2 - inset
        let rx = min(size.width / 2 - orb / 2 - inset, ry * 1.8)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return ZStack {
            // 시각의 하늘 위에 오늘의 곰이 위젯 가득 서 있고, 색 다섯이 그 위로 겹쳐 둘러선다.
            // 첫 색을 기다릴 땐 앱 아이콘의 곰, 이미 고른 색이 있으면 그 색으로 칠한 곰.
            // 앱의 원형 팔레트와 같은 모양이라 '곰을 누르면 색이 둘러선다'는 한 동작으로 이어진다.
            SkyView(theme: theme, date: date)

            currentBear
                .padding(8)
                .frame(width: size.width, height: size.height)

            ForEach(Array(palette.swatches.enumerated()), id: \.element.id) { index, swatch in
                // 12시에서 시작해 시계 방향으로. 앱의 원형 팔레트와 같은 순서.
                let angle = -Double.pi / 2 + Double(index) * 2 * .pi / Double(palette.swatches.count)

                Button(intent: RecordColorIntent(hex: swatch.hex, slot: target)) {
                    Circle()
                        .fill(swatch.color)
                        // 같은 색 배경 위에서도 원이 묻히지 않도록 바탕색 테두리를 두른다.
                        .overlay {
                            Circle().strokeBorder(theme.surface.opacity(0.92), lineWidth: max(2, orb * 0.06))
                        }
                        .shadow(color: .black.opacity(0.22), radius: orb * 0.16, y: orb * 0.06)
                }
                .buttonStyle(.plain)
                .frame(width: orb, height: orb)
                .position(
                    x: center.x + cos(angle) * rx,
                    y: center.y + sin(angle) * ry
                )
                .accessibilityLabel("\(target.displayName)에 \(swatch.name) 기록")
            }
        }
    }
}

#if DEBUG

/// 실제 위젯 프레임(포인트 기준, iPhone 17).
let todayWidgetSizes: [(name: String, size: CGSize)] = [
    ("Small", CGSize(width: 158, height: 158)),
    ("Medium", CGSize(width: 338, height: 158)),
    ("Large", CGSize(width: 338, height: 354)),
]

#Preview("오늘 위젯") {
    let palette = Palette(preset: .pantone)
    let hexes = palette.swatches.map(\.hex)
    ScrollView {
        VStack(spacing: 16) {
            ForEach(todayWidgetSizes, id: \.name) { _, size in
                HStack(spacing: 12) {
                    TodayColorView(date: .now, colors: [], target: nil, palette: palette)
                    TodayColorView(date: .now, colors: [hexes[0], "", ""], target: .afternoon, palette: palette)
                    TodayColorView(date: .now, colors: [hexes[0], "", hexes[3]], target: nil, palette: palette)
                }
                .frame(height: size.height)
            }
        }
        .padding()
    }
}

#endif
