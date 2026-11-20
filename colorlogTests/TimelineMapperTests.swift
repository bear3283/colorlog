//
//  TimelineMapperTests.swift
//  colorlogTests
//
//  오늘을 원점으로 한 5열 좌표계. 날짜 ↔ 칸이 어긋나면 기록이 엉뚱한 칸에 앉는다.
//

import Foundation
import Testing
@testable import colorlog

struct TimelineMapperTests {

    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test("칸 ↔ 날짜 왕복", arguments: [-1000, -37, -6, -5, -3, -1, 0, 1, 2, 3, 50])
    func roundTrip(offset: Int) throws {
        let calendar = Self.calendar("Asia/Seoul")
        let mapper = TimelineMapper(today: Self.date(2026, 11, 20, in: calendar), calendar: calendar)
        let day = mapper.date(offsetBy: offset)
        let position = try #require(mapper.position(of: day))
        #expect(mapper.dayOffset(row: position.row, column: position.column) == offset)
        #expect(mapper.date(row: position.row, column: position.column) == day)
    }

    @Test("오늘은 0행 가운데 칸")
    func todayIsCenter() throws {
        let calendar = Self.calendar("Asia/Seoul")
        let now = Self.date(2026, 11, 20, hour: 23, in: calendar)
        let mapper = TimelineMapper(today: now, calendar: calendar)
        let position = try #require(mapper.position(of: now))
        #expect(position.row == 0)
        #expect(position.column == TimelineMapper.centerColumn)
    }

    @Test("서머타임 전환일에도 행 구간은 닷새, 칸은 자정")
    func daylightSavingRows() {
        let calendar = Self.calendar("America/Los_Angeles")
        // 2026-03-08, 2026-11-01: 미국 서머타임 시작 · 끝
        for today in [Self.date(2026, 3, 8, in: calendar), Self.date(2026, 11, 1, in: calendar)] {
            let mapper = TimelineMapper(today: today, calendar: calendar)
            for row in -2...1 {
                let range = mapper.dayRange(row: row)
                let days = calendar.dateComponents([.day], from: range.start, to: range.end).day
                #expect(days == TimelineMapper.columnCount)
                for column in 0..<TimelineMapper.columnCount {
                    let cell = mapper.date(row: row, column: column)
                    #expect(calendar.startOfDay(for: cell) == cell)
                }
            }
        }
    }
}
