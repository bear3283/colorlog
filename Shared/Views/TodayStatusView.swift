//
//  TodayStatusView.swift
//  colorlog (앱 · 위젯 공용)
//
//  잠금 화면 위젯의 얼굴. 오늘 세 자리가 어디까지 찼는지만 보여 준다.
//
//   · 원형 — 세 칸으로 나뉜 고리(12시부터 시계 방향으로 아침 · 점심 · 저녁).
//            찬 자리는 굵게, 빈 자리는 가늘고 옅게. 가운데는 지금 물어보는 시간대 기호와 "2/3".
//   · 직사각형 — "점심 색 고를 차례" 한 줄 + 세 자리의 시간대 기호와 모양.
//   · 인라인 — 시계 위 한 줄. 시간대 기호 + "점심 색 고를 차례 · 1/3".
//
//  잠금 화면은 늘 단색(vibrant)으로 그려지므로 색이 아니라 굵기 · 모양 · 글로 말한다.
//  색을 그대로 보여 줄 수 있는 곳(fullColor)에서만 고리에 실제 색을 쓴다.
//

import SwiftUI
import WidgetKit

struct TodayStatusView: View {
    let family: WidgetFamily
    let slots: TodaySlots

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryInline: inline
            default: rectangular
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slots.accessibilityText)
    }

    // MARK: 원형

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            ring.padding(4)
            VStack(spacing: 0) {
                Image(systemName: slots.centerSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .widgetAccentable()
                Text(verbatim: slots.progressText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    private var ring: some View {
        let count = DailyColorLog.Slot.allCases.count
        let gap = 0.035
        return ZStack {
            ForEach(DailyColorLog.Slot.allCases) { slot in
                let filled = slots.mark(for: slot).isFilled
                let start = Double(slot.index) / Double(count)
                Circle()
                    .trim(from: start + gap, to: start + 1 / Double(count) - gap)
                    .stroke(
                        segmentStyle(slot, filled: filled),
                        style: StrokeStyle(lineWidth: filled ? 5.5 : 2.5, lineCap: .round))
                    .opacity(filled ? 1 : 0.4)
                    .widgetAccentable(filled)
                    // 지금 물어보는 빈 자리는 고리 위에 조금 더 진하게 — '여기를 채울 차례'.
                    .overlay {
                        if slot == slots.target && !filled {
                            Circle()
                                .trim(from: start + gap, to: start + 1 / Double(count) - gap)
                                .stroke(.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [2, 3]))
                        }
                    }
            }
        }
        .rotationEffect(.degrees(-90))
    }

    private func segmentStyle(_ slot: DailyColorLog.Slot, filled: Bool) -> AnyShapeStyle {
        guard filled, renderingMode == .fullColor else { return AnyShapeStyle(.primary) }
        return AnyShapeStyle(Color(hex: slots.hex(at: slot), fallback: .primary))
    }

    // MARK: 직사각형

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(slots.headline)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                Spacer(minLength: 2)
                Text(verbatim: slots.progressText)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .opacity(0.8)
            }
            TodaySlotMarks(slots: slots, symbolSize: 15, spacing: 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: 인라인

    private var inline: some View {
        Label {
            // 요약은 이미 현지화된 문장이고 "2/3"은 번역할 것이 없다.
            Text(verbatim: "\(slots.headline) · \(slots.progressText)")
        } icon: {
            Image(systemName: slots.centerSymbol)
        }
    }
}

#if DEBUG
#Preview("잠금 화면", traits: .sizeThatFitsLayout) {
    let palette = Palette(preset: .pantone)
    let hexes = palette.swatches.map(\.hex)
    let cases: [TodaySlots] = [
        TodaySlots(colors: ["", "", ""], target: .morning, palette: palette),
        TodaySlots(colors: [hexes[0], "", ""], target: .afternoon, palette: palette),
        TodaySlots(colors: hexes.prefix(3).map { $0 }, target: nil, palette: palette),
    ]
    VStack(spacing: 12) {
        ForEach(Array(cases.enumerated()), id: \.offset) { _, slots in
            HStack(spacing: 12) {
                TodayStatusView(family: .accessoryCircular, slots: slots).frame(width: 72, height: 72)
                TodayStatusView(family: .accessoryRectangular, slots: slots).frame(width: 172, height: 76)
            }
            TodayStatusView(family: .accessoryInline, slots: slots)
        }
    }
    .padding()
    .background(.black)
    .foregroundStyle(.white)
}
#endif
