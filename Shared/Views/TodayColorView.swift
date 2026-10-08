//
//  TodayColorView.swift
//  colorlog (앱 · 위젯 공용)
//
//  홈 화면 위젯의 얼굴. 위젯은 **오늘이라는 칸 하나를 크게 키운 것**이다.
//
//  얼굴은 둘뿐이고, 둘 다 글자가 없다.
//
//   · 칠해진 얼굴 — 위젯 전체가 오늘 고른 색으로 가장자리까지 칠해진다.
//     앱 격자의 오늘 칸과 같은 시드를 쓰므로 경계 각도까지 똑같다.
//     아직 아무것도 고르지 않았으면 앱의 빈 칸과 같은 빈 색.
//
//   · 고르는 얼굴 — 물어보는 시각이 되면 하늘이 깔리고, 가운데의 오늘 칸
//     둘레로 색 다섯이 둘러선다. 앱의 원형 팔레트와 같은 모양이라
//     '칸을 누르면 색이 둘러선다'는 한 가지 동작으로 두 표면이 이어진다.
//
//  두 얼굴은 모양부터 다르다. 칠해진 얼굴은 가장자리까지 꽉 찬 면이고,
//  고르는 얼굴은 하늘 위에 떠 있는 알들이다. 그래서 '지금 고를 차례'라는 걸
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

    /// 오늘 고른 색으로 가장자리까지 칠한 면. 칠해진 얼굴과 고르는 얼굴의 배경이 함께 쓴다.
    private var colorField: some View {
        ZStack {
            theme.background
            FlatColorFill(pigments: pigments, seed: day.colorSeed)
        }
    }

    @ViewBuilder
    private var paintedFace: some View {
        let emptyTone = theme.stroke.opacity(theme.colorScheme == .dark ? 0.58 : 0.74)

        if !hasColors {
            // 앱 격자의 '오늘 · 비어 있음'과 같은 배합.
            ZStack {
                theme.background
                emptyTone
            }
            .accessibilityLabel("오늘 아직 기록 없음")
        } else {
            colorField
            .accessibilityLabel("오늘 색 \(pigments.count { $0 != nil })개 기록됨")
        }
    }

    // MARK: 고르는 얼굴

    private func chooser(in size: CGSize, target: DailyColorLog.Slot) -> some View {
        let short = min(size.width, size.height)
        let orb = min(short * 0.24, 54)
        let cell = min(short * 0.23, 76)
        let inset = short * 0.075

        // 정사각형이면 원, 가로로 긴 위젯이면 타원으로 둘러선다.
        // 타원을 가로 끝까지 펴면 색들이 흩어져 '칸에서 나온 것'으로 읽히지 않는다.
        let ry = size.height / 2 - orb / 2 - inset
        let rx = min(size.width / 2 - orb / 2 - inset, ry * 1.8)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return ZStack {
            if hasColors {
                // 이미 고른 색이 있으면 그 색들이 배경이 된다. 지금까지의 하루 위에
                // 다음 색을 얹는다는 게 보이도록. 살짝 가라앉혀 '칠해진 얼굴'과 구분하고
                // 그 위의 색 다섯을 띄운다.
                // ⚠️ 막은 반드시 검정. theme.ink는 어두운 팔레트에서 크림색이라
                // 가라앉히는 대신 배경을 뿌옇게 바래게 만든다.
                colorField
                Color.black.opacity(0.16)
            } else {
                // 첫 색을 고를 때는 칠할 것이 없다. 시각의 하늘 위에 빈 오늘 칸.
                SkyView(theme: theme, date: date)

                DailyCellView(date: day, colors: colors, relation: .today, isHighlighted: true)
                    .frame(width: cell, height: cell)
                    .position(center)
            }

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
