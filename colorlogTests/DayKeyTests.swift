//
//  DayKeyTests.swift
//  colorlogTests
//
//  저장값은 '기록한 시간대의 자정'. 시간대를 옮겨도 기록이 원래 날의 칸에 앉는지.
//

import Foundation
import SwiftData
import Testing
@testable import colorlog

@MainActor
struct DayKeyTests {

    static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    static let seoul = calendar("Asia/Seoul")
    static let losAngeles = calendar("America/Los_Angeles")

    static func midnight(_ y: Int, _ m: Int, _ d: Int, in calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!)
    }

    // MARK: 날 읽기

    @Test("같은 시간대: 자정 경계 23:59:59 · 00:00:00 · 00:00:01")
    func sameZoneBoundaries() {
        let cal = Self.seoul
        let midnight = Self.midnight(2026, 11, 20, in: cal)
        #expect(DayKey(midnight.addingTimeInterval(-1), calendar: cal) == DayKey(year: 2026, month: 11, day: 19))
        #expect(DayKey(midnight, calendar: cal) == DayKey(year: 2026, month: 11, day: 20))
        #expect(DayKey(midnight.addingTimeInterval(1), calendar: cal) == DayKey(year: 2026, month: 11, day: 20))
        #expect(DayKey(recordedMidnight: midnight, calendar: cal) == DayKey(year: 2026, month: 11, day: 20))
    }

    /// (기록한 곳, 지금 보는 곳)
    nonisolated static let zonePairs: [(String, String)] = [
        ("Asia/Seoul", "America/Los_Angeles"),
        ("America/Los_Angeles", "Asia/Seoul"),
        ("Asia/Seoul", "Europe/London"),
        ("Pacific/Auckland", "America/New_York"),
        ("America/New_York", "Pacific/Auckland"),
        ("Asia/Kolkata", "America/Los_Angeles"),
        ("Pacific/Auckland", "America/Los_Angeles"),
        ("Pacific/Tongatapu", "America/Los_Angeles"),
        ("Pacific/Honolulu", "Asia/Seoul"),
        ("Pacific/Honolulu", "Pacific/Auckland"),
        ("UTC", "Asia/Seoul"),
    ]

    @Test("다른 시간대에서 남긴 기록도 원래 날로 읽힌다", arguments: zonePairs)
    func recordedElsewhere(pair: (String, String)) {
        let recorded = Self.calendar(pair.0)
        let viewing = Self.calendar(pair.1)
        // 서머타임 시작 · 끝 무렵을 포함해 한 해 곳곳.
        for (m, d) in [(1, 1), (3, 8), (3, 29), (6, 30), (10, 5), (11, 1), (11, 20), (12, 31)] {
            let stored = Self.midnight(2026, m, d, in: recorded)
            #expect(DayKey(recordedMidnight: stored, calendar: viewing) == DayKey(year: 2026, month: m, day: d),
                    "\(pair.0) → \(pair.1) \(m)/\(d)")
        }
    }

    @Test("범위 밖 시간대(UTC+14 키리바시)의 기록은 다른 곳에서 하루 어긋난다 — 알려진 한계")
    func outOfRangeZoneLimitation() {
        let kiritimati = Self.calendar("Pacific/Kiritimati")
        let stored = Self.midnight(2026, 11, 20, in: kiritimati)   // = 11/19 00:00 하와이
        // 그 시간대 안에서는 맞다.
        #expect(DayKey(recordedMidnight: stored, calendar: kiritimati) == DayKey(year: 2026, month: 11, day: 20))
        // 다른 곳에서는 하와이(−10)의 자정으로 읽힌다.
        #expect(DayKey(recordedMidnight: stored, calendar: Self.seoul) == DayKey(year: 2026, month: 11, day: 19))
    }

    @Test("날의 자정으로 되돌리기: 칸 날짜와 같다")
    func startOfDayRoundTrip() {
        for cal in [Self.seoul, Self.losAngeles, Self.calendar("Asia/Kolkata")] {
            let mapper = TimelineMapper(today: Self.midnight(2026, 3, 8, in: cal), calendar: cal)
            for offset in -40...5 {
                let cell = mapper.date(offsetBy: offset)
                #expect(DayKey(cell, calendar: cal).startOfDay(in: cal) == cell)
            }
        }
    }

    // MARK: 저장소에서 — 버그 시나리오 (dev.md 2.3)

    @Test("서울 기록을 LA에서: 11/20 칸에 보이고, 그 칸을 고치면 같은 기록이 바뀐다")
    func seoulRecordViewedInLosAngeles() throws {
        let container = ColorLogStore.inMemory()
        let context = container.mainContext
        let seoulDay = Self.midnight(2026, 11, 20, in: Self.seoul)
        try context.setColor("#FF0000", for: .morning, on: seoulDay, palette: .default, calendar: Self.seoul)

        // LA에서 행 하나(오늘 = 11/20)를 읽는다.
        let la = Self.losAngeles
        let mapper = TimelineMapper(today: Self.midnight(2026, 11, 20, in: la), calendar: la)
        let range = mapper.dayRange(row: 0)
        let widened = DailyColorLog.candidateRange(from: range.start, until: range.end, calendar: la)
        let rowLogs = try context.fetch(FetchDescriptor(predicate: DailyColorLog.predicate(from: widened.start, until: widened.end)))
        let lookup = DailyColorLog.byDay(rowLogs, calendar: la)

        let cell1120 = mapper.date(offsetBy: 0)
        let cell1119 = mapper.date(offsetBy: -1)
        #expect(lookup[DayKey(cell1120, calendar: la)]?.slotColors == ["#FF0000", "", ""])
        #expect(lookup[DayKey(cell1119, calendar: la)] == nil)

        // LA에서 11/19 칸에 색을 넣어도 서울 11/20 기록은 그대로다.
        try context.setColor("#00FF00", for: .evening, on: cell1119, palette: .default, calendar: la)
        // 11/20 칸을 고치면 서울 기록이 바뀐다(새 레코드를 만들지 않는다).
        try context.setColor("#0000FF", for: .afternoon, on: cell1120, palette: .default, calendar: la)

        let all = try context.fetch(FetchDescriptor<DailyColorLog>(sortBy: [SortDescriptor(\.date)]))
        #expect(all.count == 2)
        let byDay = DailyColorLog.byDay(all, calendar: la)
        #expect(byDay[DayKey(year: 2026, month: 11, day: 20)]?.slotColors == ["#FF0000", "#0000FF", ""])
        #expect(byDay[DayKey(year: 2026, month: 11, day: 20)]?.date == seoulDay)
        #expect(byDay[DayKey(year: 2026, month: 11, day: 19)]?.slotColors == ["", "", "#00FF00"])
    }

    @Test("한 날에 시간대가 다른 기록이 둘이면 지금 시간대의 자정 기록을 쓴다")
    func duplicatePickPrefersLocalMidnight() throws {
        let container = ColorLogStore.inMemory()
        let context = container.mainContext
        try context.setColor("#111111", for: .morning, on: Self.midnight(2026, 11, 20, in: Self.losAngeles),
                             palette: .default, calendar: Self.losAngeles)
        // 서울로 돌아와 같은 날에 또 기록 — 서울 자정 키는 LA 기록과 다르므로 setColor는 LA 기록을 고친다.
        try context.setColor("#222222", for: .afternoon, on: Self.midnight(2026, 11, 20, in: Self.seoul),
                             palette: .default, calendar: Self.seoul)
        let all = try context.fetch(FetchDescriptor<DailyColorLog>())
        #expect(all.count == 1)
        #expect(all.first?.slotColors == ["#111111", "#222222", ""])

        // 예전 버전이 이미 겹쳐 만든 두 레코드(서울 자정 + LA 자정)가 있다면 서울에서는 서울 쪽.
        context.insert(DailyColorLog(date: Self.midnight(2026, 11, 20, in: Self.seoul), colors: ["#333333"], calendar: Self.seoul))
        try context.save()
        let both = try context.fetch(FetchDescriptor<DailyColorLog>())
        #expect(both.count == 2)
        let picked = DailyColorLog.pick(both, for: DayKey(year: 2026, month: 11, day: 20), calendar: Self.seoul)
        #expect(picked?.slotColors.first == "#333333")
    }
}
