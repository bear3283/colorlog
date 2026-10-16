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
//     아직 아무것도 고르지 않았으면 곰은 색 없이 자고 있다.
//
//   · 고르는 얼굴 — 물어보는 시각이 되면 하늘이 깔리고, 가운데 곰 둘레로
//     색 다섯이 둘러선다. 첫 색을 기다릴 땐 곰이 시무룩하게 앉아 있다.
//     앱의 원형 팔레트와 같은 모양이라 '칸을 누르면 색이 둘러선다'는 한 가지
//     동작으로 두 표면이 이어진다.
//
//  두 얼굴은 바탕부터 다르다. 칠해진 얼굴은 팔레트 바탕 위의 곰이고,
//  고르는 얼굴은 하늘 위에 색 알들이 떠 있다. 그래서 '지금 고를 차례'라는 걸
//  문장 없이도 알 수 있다.
//

import AppIntents
import SwiftUI

struct TodayColorView: View {

    /// 그리는 시각. 고르는 얼굴의 하늘이 이 시각을 따른다.
    let date: Date
    /// 오늘의 자리별 색. ""는 빈 자리.
    let colors: [String]
    /// 지금 물어보는 자리. nil이면 칠해진 얼굴.
    let target: DailyColorLog.Slot?
    var palette: ColorPalette = .default

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
            if let target {
                chooser(in: proxy.size, target: target)
            } else {
                paintedFace
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

    /// 칠해진 얼굴. 물어볼 차례가 아닐 때의 위젯.
    ///
    /// 아직 아무것도 고르지 않았으면 곰은 자고 있다 — 물어보는 시각이 오면 깨어나
    /// 색 다섯 사이에 시무룩하게 앉는다. 고른 색이 있으면 그 색으로 칠한 오늘의 곰.
    private var paintedFace: some View {
        let bear = hasColors
            ? DayBear(date: day, filledCount: filledCount, relation: .today)
            : DayBear(pose: BearState.sleeping.pose ?? .sleeping, style: .bare)

        return ZStack {
            theme.background
            todayBear(bear)
                .padding(8)
        }
        .accessibilityElement()
        .accessibilityLabel(hasColors ? "오늘 색 \(filledCount)개 기록됨" : "오늘 아직 기록 없음")
    }

    // MARK: 고르는 얼굴

    private func chooser(in size: CGSize, target: DailyColorLog.Slot) -> some View {
        let short = min(size.width, size.height)
        let orb = min(short * 0.24, 54)
        // 곰은 둘러선 색 안쪽에 들어가야 한다. 세로 반지름에서 색 한 알만큼 비운 크기.
        let bearSide = min(short * 0.36, 128)
        let inset = short * 0.075

        // 정사각형이면 원, 가로로 긴 위젯이면 타원으로 둘러선다.
        // 타원을 가로 끝까지 펴면 색들이 흩어져 '칸에서 나온 것'으로 읽히지 않는다.
        let ry = size.height / 2 - orb / 2 - inset
        let rx = min(size.width / 2 - orb / 2 - inset, ry * 1.8)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return ZStack {
            // 시각의 하늘 위, 색 다섯이 둘러선 한가운데에 오늘의 곰이 앉는다.
            // 첫 색을 기다릴 땐 색 없이 시무룩하게, 이미 고른 색이 있으면 그 색으로 칠한 채.
            // 앱의 원형 팔레트와 같은 모양이라 '곰을 누르면 색이 둘러선다'는 한 동작으로 이어진다.
            SkyView(theme: theme, date: date)

            todayBear(DayBear(date: day, filledCount: filledCount, relation: .today))
                .frame(width: bearSide, height: bearSide)
                .position(center)

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
    let palette = ColorPalette.pantone
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
