//
//  MonthPosterTests.swift
//  colorlogTests
//
//  월간 곰 포스터가 그 달의 날을 바른 요일 칸에 앉히고, 색 비율과 칠한 날 수를 바르게 세는지.
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import colorlog

@MainActor
struct MonthPosterTests {

    private static func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test("2026년 11월: 1일은 일요일 — 일요일 시작이면 빈칸 0, 월요일 시작이면 6, 날은 30개")
    func leadingBlanks() {
        let sunday = Self.calendar(firstWeekday: 1)
        let monday = Self.calendar(firstWeekday: 2)
        let a = MonthPoster(month: Self.date(2026, 11, 15, sunday), records: [:], calendar: sunday)
        let b = MonthPoster(month: Self.date(2026, 11, 15, monday), records: [:], calendar: monday)
        #expect(a.cells.prefix { $0 == nil }.count == 0)
        #expect(b.cells.prefix { $0 == nil }.count == 6)
        #expect(a.cells.compactMap { $0 }.count == 30)
        #expect(a.cells.compactMap { $0 }.map(\.key.day) == Array(1...30))
        #expect(a.monthStart == Self.date(2026, 11, 1, sunday))
    }

    @Test("윤년 2월은 29일")
    func leapFebruary() {
        let calendar = Self.calendar(firstWeekday: 1)
        let poster = MonthPoster(month: Self.date(2028, 2, 10, calendar), records: [:], calendar: calendar)
        #expect(poster.cells.compactMap { $0 }.count == 29)
    }

    @Test("색 비율은 많은 순, 같으면 먼저 나온 순 · HEX 표기 차이는 같은 색 · 칠한 날 수")
    func colorCounts() {
        let calendar = Self.calendar(firstWeekday: 1)
        let records: [DayKey: (colors: [String], pose: String?)] = [
            DayKey(year: 2026, month: 11, day: 2): (["#AA0000", "", "#00AA00"], nil),
            DayKey(year: 2026, month: 11, day: 3): (["#00aa00", "#0000AA", ""], "reading"),
            DayKey(year: 2026, month: 11, day: 4): (["", "", ""], nil),
            DayKey(year: 2026, month: 10, day: 31): (["#FFFFFF", "", ""], nil),  // 다른 달은 세지 않음
        ]
        let poster = MonthPoster(month: Self.date(2026, 11, 1, calendar), records: records, calendar: calendar)
        #expect(poster.colorCounts.map(\.hex) == ["#00AA00", "#AA0000", "#0000AA"])
        #expect(poster.colorCounts.map(\.count) == [2, 1, 1])
        #expect(poster.recordedDays == 2)
        let third = poster.cells.compactMap { $0 }.first { $0.key.day == 3 }
        #expect(third?.poseRawValue == "reading")
    }

    @Test("저장소에서 그 달의 기록만 읽는다(읽기만 하고 쓰지 않음)")
    func loadFromStore() throws {
        let calendar = Calendar.current
        let container = ColorLogStore.inMemory()
        let context = container.mainContext
        let palette = Palette(preset: .pantone)
        let hex = palette.swatches[0].hex
        let start = calendar.dateInterval(of: .month, for: .now)!.start
        let inMonth = calendar.date(byAdding: .day, value: 4, to: start)!
        let before = calendar.date(byAdding: .day, value: -1, to: start)!
        try context.setColor(hex, for: .morning, on: inMonth, palette: palette)
        try context.setColor(hex, for: .evening, on: before, palette: palette)
        let countBefore = try context.fetchCount(FetchDescriptor<DailyColorLog>())

        let poster = try MonthPoster.load(month: start, context: context, calendar: calendar)
        #expect(poster.recordedDays == 1)
        #expect(poster.colorCounts.first?.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<DailyColorLog>()) == countBefore)
    }

    @Test("포스터 이미지는 1080×1440으로 렌더된다")
    func renderSize() throws {
        let poster = MonthPoster(month: .now, records: [:])
        let image = try #require(MonthPosterView(poster: poster).rendered())
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1440)
    }
}
