//
//  TodaySlotsTests.swift
//  colorlogTests
//
//  틴트 · 투명 홈 화면과 잠금 화면에서 색 대신 쓰는 모양 · 글이 오늘 세 자리를 바르게 말하는지.
//

import Foundation
import Testing
@testable import colorlog

struct TodaySlotsTests {

    private let palette = Palette(preset: .pantone)
    private var hexes: [String] { palette.swatches.map(\.hex) }

    @Test("빈 자리는 점선 고리, 찬 자리는 그 색의 팔레트 순서 기호")
    func marks() {
        let slots = TodaySlots(colors: [hexes[2], "", hexes[0]], target: nil, palette: palette)
        #expect(slots.mark(for: .morning) == .filled(symbol: SwatchMark.symbol(for: 2)))
        #expect(slots.mark(for: .afternoon) == .empty)
        #expect(slots.mark(for: .evening) == .filled(symbol: SwatchMark.symbol(for: 0)))
        #expect(slots.mark(for: .afternoon).symbol == "circle.dashed")
        #expect(slots.filledCount == 2)
        #expect(slots.progressText == "2/3")
        #expect(slots.nextEmpty == .afternoon)
    }

    @Test("HEX 대소문자 · # 유무와 상관없이 팔레트 색을 찾고, 팔레트에 없는 색은 기본 원")
    func lookup() {
        let lower = hexes[1].lowercased().replacingOccurrences(of: "#", with: "")
        let slots = TodaySlots(colors: [lower, "#123456", ""], target: nil, palette: palette)
        #expect(slots.mark(for: .morning) == .filled(symbol: SwatchMark.symbol(for: 1)))
        #expect(slots.mark(for: .afternoon) == .filled(symbol: "circle.fill"))
    }

    @Test("자리 배열이 짧아도 빈 자리로 본다")
    func shortColors() {
        let slots = TodaySlots(colors: [hexes[0]], target: .afternoon, palette: palette)
        #expect(slots.filledCount == 1)
        #expect(slots.mark(for: .evening) == .empty)
    }

    @Test("가운데 기호: 물어보는 자리 → 그 시간대, 다 찼으면 체크, 아니면 다음 빈 자리")
    func centerSymbol() {
        #expect(TodaySlots(colors: ["", "", ""], target: .evening, palette: palette).centerSymbol
                == DailyColorLog.Slot.evening.symbolName)
        #expect(TodaySlots(colors: Array(hexes.prefix(3)), target: nil, palette: palette).centerSymbol
                == "checkmark")
        #expect(TodaySlots(colors: [hexes[0], "", ""], target: nil, palette: palette).centerSymbol
                == DailyColorLog.Slot.afternoon.symbolName)
    }

    @Test("한 줄 요약과 VoiceOver 문장에 자리별 상태가 담긴다")
    func texts() {
        let asking = TodaySlots(colors: [hexes[0], "", ""], target: .afternoon, palette: palette)
        #expect(asking.headline.contains(DailyColorLog.Slot.afternoon.displayName))
        #expect(asking.accessibilityText.contains(palette.swatches[0].name))
        #expect(asking.accessibilityText.hasPrefix(asking.headline))

        let done = TodaySlots(colors: Array(hexes.prefix(3)), target: nil, palette: palette)
        #expect(done.isComplete)
        #expect(done.headline != asking.headline)
    }
}
