//
//  MonthPoster.swift
//  colorlog
//
//  한 달 기록을 한 장의 그림(월간 곰 포스터)으로 만드는 데 필요한 값.
//  그림은 `MonthPosterView`가 그리고, 여기서는 '그 달에 어떤 날이 어디에 앉는지'만 정한다.
//  저장소를 읽기만 한다. 아무것도 쓰지 않는다.
//

import Foundation
import SwiftData

nonisolated struct MonthPoster: Equatable, Sendable {

    struct Day: Equatable, Sendable {
        let key: DayKey
        /// 자리 순서의 HEX. ""는 빈 자리.
        let colors: [String]
        let poseRawValue: String?

        var filledColors: [String] { colors.filter { !$0.isEmpty } }
    }

    /// 그 달의 1일(지금 달력의 자정).
    let monthStart: Date
    /// 달력 칸. 앞쪽 빈칸(1일 전 요일)은 nil.
    let cells: [Day?]
    /// 기록된 색과 그 횟수. 많은 순, 같으면 먼저 나온 순.
    let colorCounts: [(hex: String, count: Int)]
    /// 색이 하나라도 있는 날 수.
    let recordedDays: Int

    static func == (lhs: MonthPoster, rhs: MonthPoster) -> Bool {
        lhs.monthStart == rhs.monthStart && lhs.cells == rhs.cells
    }

    /// `date`가 든 달의 포스터. `byDay`는 그 달의 기록(날 → 자리별 색 · 자세).
    init(month date: Date, records byDay: [DayKey: (colors: [String], pose: String?)], calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        monthStart = start
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        // 1일 앞의 빈칸 — 달력의 첫 요일(지역 설정)부터 센다.
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7

        var cells: [Day?] = Array(repeating: nil, count: leading)
        var order: [String] = []
        var counts: [String: Int] = [:]
        var recorded = 0
        for offset in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let key = DayKey(date, calendar: calendar)
            let record = byDay[key]
            let colors = record?.colors ?? []
            let day = Day(key: key, colors: colors, poseRawValue: record?.pose)
            cells.append(day)
            if !day.filledColors.isEmpty { recorded += 1 }
            for hex in day.filledColors {
                let normalized = HexColor.normalized(hex) ?? hex
                if counts[normalized] == nil { order.append(normalized) }
                counts[normalized, default: 0] += 1
            }
        }
        self.cells = cells
        self.recordedDays = recorded
        self.colorCounts = order
            .enumerated()
            .sorted { lhs, rhs in
                let (a, b) = (counts[lhs.element]!, counts[rhs.element]!)
                return a != b ? a > b : lhs.offset < rhs.offset
            }
            .map { ($0.element, counts[$0.element]!) }
    }
}

extension MonthPoster {
    /// 저장소에서 그 달의 기록을 읽어 포스터를 만든다.
    @MainActor
    static func load(month date: Date, context: ModelContext, calendar: Calendar = .current) throws -> MonthPoster {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return MonthPoster(month: date, records: [:], calendar: calendar)
        }
        let range = DailyColorLog.candidateRange(from: interval.start, until: interval.end, calendar: calendar)
        let logs = try context.fetch(FetchDescriptor<DailyColorLog>(
            predicate: DailyColorLog.predicate(from: range.start, until: range.end)))
        let records = DailyColorLog.byDay(logs, calendar: calendar)
            .mapValues { (colors: $0.slotColors, pose: $0.pose?.rawValue) }
        return MonthPoster(month: date, records: records, calendar: calendar)
    }
}
