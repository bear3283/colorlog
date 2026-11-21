//
//  TodaySlots.swift
//  colorlog (앱 · 위젯 공용)
//
//  오늘 세 자리(아침 · 점심 · 저녁)가 어디까지 찼는지를 **색 없이** 말하는 방법.
//
//  홈 화면 틴트 · 투명 모드와 잠금 화면에서는 시스템이 위젯을 한 가지 색으로 다시 칠한다.
//  색 자체가 콘텐츠인 앱이라 그대로 두면 곰도 색 알도 같은 회색 덩어리가 된다.
//  그래서 이런 자리에서는 색 대신
//   · 모양 — 찬 자리는 그 색이 팔레트 몇 번째인지의 기호(●▲■◆★…, '색상 없이 구별'과 같은 기호),
//            빈 자리는 점선 고리
//   · 짧은 글 — "점심 색 고를 차례", "2/3"
//  으로 같은 뜻을 전한다.
//

import SwiftUI
import WidgetKit

nonisolated struct TodaySlots: Equatable {

    /// 자리 순서의 HEX. ""는 빈 자리.
    let colors: [String]
    /// 지금 물어보는 자리. nil이면 물어볼 차례가 아님.
    let target: DailyColorLog.Slot?
    let palette: Palette

    enum Mark: Equatable {
        /// 빈 자리.
        case empty
        /// 찬 자리. 팔레트 안 순서의 기호. 지금 팔레트에 없는 색이면 기본 원.
        case filled(symbol: String)

        var isFilled: Bool { self != .empty }

        var symbol: String {
            switch self {
            case .empty: "circle.dashed"
            case .filled(let symbol): symbol
            }
        }
    }

    func hex(at slot: DailyColorLog.Slot) -> String {
        colors.indices.contains(slot.index) ? colors[slot.index] : ""
    }

    func mark(for slot: DailyColorLog.Slot) -> Mark {
        let hex = hex(at: slot)
        guard !hex.isEmpty else { return .empty }
        guard let normalized = HexColor.normalized(hex),
              let index = palette.swatches.firstIndex(where: { $0.hex.uppercased() == normalized })
        else { return .filled(symbol: "circle.fill") }
        return .filled(symbol: SwatchMark.symbol(for: index))
    }

    var filledCount: Int { DailyColorLog.Slot.allCases.count { mark(for: $0).isFilled } }

    var isComplete: Bool { filledCount == DailyColorLog.Slot.allCases.count }

    /// 아직 비어 있는 첫 자리.
    var nextEmpty: DailyColorLog.Slot? {
        DailyColorLog.Slot.allCases.first { !mark(for: $0).isFilled }
    }

    /// "2/3". 숫자와 빗금뿐이라 번역하지 않는다.
    var progressText: String { "\(filledCount)/\(DailyColorLog.Slot.allCases.count)" }

    /// 가운데 기호: 물어보는 자리 → 그 시간대, 다 찼으면 체크, 아니면 다음 빈 자리의 시간대.
    var centerSymbol: String {
        if let target { return target.symbolName }
        if isComplete { return "checkmark" }
        return (nextEmpty ?? .morning).symbolName
    }

    /// 한 줄 요약. 잠금 화면 직사각형 · 인라인과 틴트 위젯이 쓴다.
    var headline: String {
        if let target {
            return String(localized: "\(target.displayName) 색 고를 차례", comment: "잠금 화면 · 틴트 위젯. 지금 물어보는 자리(아침 · 점심 · 저녁)")
        }
        if isComplete {
            return String(localized: "오늘 세 색 다 칠했어요", comment: "잠금 화면 · 틴트 위젯. 세 자리가 다 찼을 때")
        }
        return String(localized: "오늘의 색")
    }

    /// VoiceOver: "점심 색 고를 차례, 아침 분홍, 점심 비어 있음, 저녁 비어 있음".
    var accessibilityText: String {
        let slots = DailyColorLog.Slot.allCases.map { slot in
            let hex = hex(at: slot)
            let name = hex.isEmpty
                ? String(localized: "비어 있음", comment: "VoiceOver. 색이 없는 자리")
                : (palette.swatch(for: hex)?.name ?? String(localized: "기록된 색", comment: "VoiceOver. 이름을 모르는 색"))
            return "\(slot.displayName) \(name)"
        }
        return ([headline] + slots).joined(separator: ", ")
    }
}

/// 세 자리를 시간대 기호 + 모양 하나씩으로 나란히. 색이 사라지는 렌더링 모드용.
struct TodaySlotMarks: View {
    let slots: TodaySlots
    var symbolSize: CGFloat = 13
    var spacing: CGFloat = 10
    /// 시간대 기호(해 뜸 · 해 · 달)를 위에 둘지. 좁은 자리에서는 모양만.
    var showsTimeOfDay = true

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(DailyColorLog.Slot.allCases) { slot in
                let mark = slots.mark(for: slot)
                VStack(spacing: symbolSize * 0.25) {
                    if showsTimeOfDay {
                        Image(systemName: slot.symbolName)
                            .font(.system(size: symbolSize * 0.75, weight: .semibold))
                            .opacity(slot == slots.target ? 1 : 0.6)
                    }
                    Image(systemName: mark.symbol)
                        .font(.system(size: symbolSize, weight: .bold))
                        .opacity(mark.isFilled ? 1 : 0.55)
                        .widgetAccentable(mark.isFilled)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
