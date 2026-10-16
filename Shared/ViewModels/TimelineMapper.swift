//
//  TimelineMapper.swift
//  colorlog
//
//  달력이 아니라 '오늘'을 원점으로 삼는 좌표계.
//
//   -2행:  D-12 D-11 [D-10]  D-9  D-8
//   -1행:  D-7  D-6  [D-5]   D-4  D-3
//    0행:  D-2  D-1  [오늘]  D+1  D+2
//    1행:  D+3  D+4  [D+5]   D+6  D+7
//
//  => offset = (column - 2) + 5 * row
//
//  한 행은 일주일이 아니라 닷새다. 칸마다 곰이 앉으면서 일곱 마리는 너무 빽빽했다.
//  다섯이면 곰이 한 치수 커져 동작이 읽히고, 그래도 오늘은 정중앙에 놓인다(홀수).
//
//  시간은 글을 읽듯 **왼쪽에서 오른쪽으로, 위에서 아래로** 흐른다.
//  위로 올라갈수록 과거, 아래로 내려갈수록 미래다.
//  (처음엔 반대로 두었는데 — 아래로 스크롤하면 과거 — 시간이 거꾸로 흐르는
//   격자가 되어 읽는 방향과 어긋났다.)
//  오늘은 가로로도 세로로도 정중앙에 놓인다. 달력이 아니라 '지금'을 원점으로 한 좌표계다.
//

import Foundation

nonisolated struct TimelineMapper: Equatable, Sendable {

    /// 5열 고정. 중앙(오늘)이 존재하려면 홀수여야 한다.
    static let columnCount = 5
    /// 0-based 정중앙 = 3번째 칸.
    static let centerColumn = columnCount / 2   // 2

    /// 아무리 화면이 짧아도 이만큼의 미래는 보여 준다.
    static let minimumFutureRows = 3

    /// 가장 아래(가장 미래) 행. 격자가 화면 아래 끝까지 이어지도록 화면 높이가 정한다.
    /// 캔버스의 위쪽 끝은 상수가 아니라 '앱과 함께 시작한 날'이 정한다.
    static func lastRow(viewportHeight: CGFloat, cellSide: CGFloat, spacing: CGFloat) -> Int {
        let rowStride = cellSide + spacing
        guard rowStride > 0 else { return minimumFutureRows }
        let needed = Int(((viewportHeight / 2 - cellSide / 2) / rowStride).rounded(.up))
        return max(needed, minimumFutureRows)
    }

    /// 좌표계의 원점. 항상 자정으로 정규화된다.
    let today: Date
    private let calendar: Calendar

    init(today: Date = .now, calendar: Calendar = .current) {
        self.calendar = calendar
        self.today = calendar.startOfDay(for: today)
    }

    // MARK: 정방향 매핑

    /// 오늘로부터 며칠 떨어져 있는가. 과거는 음수, 미래는 양수.
    func dayOffset(row: Int, column: Int) -> Int {
        (column - Self.centerColumn) + Self.columnCount * row
    }

    func date(row: Int, column: Int) -> Date {
        date(offsetBy: dayOffset(row: row, column: column))
    }

    func date(offsetBy days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: today) ?? today
    }

    func relation(row: Int, column: Int) -> DayRelation {
        switch dayOffset(row: row, column: column) {
        case 0:      .today
        case ..<0:   .past
        default:     .future
        }
    }

    /// 한 행이 덮는 날짜 구간. [start, end) — SwiftData 조회에 그대로 넣는다.
    func dayRange(row: Int) -> (start: Date, end: Date) {
        let start = date(row: row, column: 0)
        let lastDay = date(row: row, column: Self.columnCount - 1)
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return (start, end)
    }

    // MARK: 역방향 매핑

    /// 임의의 날짜가 그리드의 어느 칸에 놓이는가.
    func position(of date: Date) -> (row: Int, column: Int)? {
        let target = calendar.startOfDay(for: date)
        guard let offset = calendar.dateComponents([.day], from: today, to: target).day else {
            return nil
        }

        // offset = (c - 2) + 5r  =>  r = floor((offset + 2) / 5)
        let row = Self.floorDiv(offset + Self.centerColumn, Self.columnCount)
        let column = offset - Self.columnCount * row + Self.centerColumn
        guard (0..<Self.columnCount).contains(column) else { return nil }
        return (row, column)
    }

    func row(containing date: Date) -> Int? {
        position(of: date)?.row
    }

    /// Swift의 `/`는 0을 향해 버림하므로 음수에서 어긋난다. 바닥 나눗셈을 따로 둔다.
    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

}
