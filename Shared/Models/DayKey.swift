//
//  DayKey.swift
//  colorlog (앱 · 위젯 공용)
//
//  '어느 날의 기록인가'를 시간대와 무관하게 비교하는 열쇠.
//
//  저장 규칙: `DailyColorLog.date`는 **기록할 때 기기 시간대의 자정**(절대 시각)이다.
//  그래서 서울에서 남긴 11/20(= 11/19 15:00Z)을 로스앤젤레스에서 보면 그 시각은
//  11/19 07:00 PST — 자정 `Date`끼리 완전 일치로 찾으면 칸이 비고,
//  `startOfDay`로 다시 맞추면 하루 앞(11/19) 칸에 앉는다.
//
//  저장된 시각 t가 어느 날 D의 자정이 되려면 t = D 00:00Z − offset (offset = 기록한 곳의 UTC 오프셋).
//  offset을 [UTC−10, UTC+14)(꼭 24시간 폭)로 보면 이 조건을 만족하는 D는 언제나 하나다.
//  하와이(−10)부터 뉴질랜드 서머타임 · 통가(+13)까지 들어간다. 폭이 24시간을 넘으면
//  뉴질랜드 기록이 −11로도 읽혀 하루 밀리는 식으로 답이 둘이 된다.
//
//  지금 시간대에서 만든 기록은 offset이 정확히 같아 언제나 그날로 읽힌다(기존 동작과 같다).
//
//  남는 한계: 저장된 값에는 원래 시간대가 없다. 범위 밖 시간대 — UTC−11 · −12(아메리칸사모아 ·
//  니우에 등)와 +14(키리바시 라인 제도) — 에서 남긴 기록을 **다른 시간대에서** 보면 하루 어긋난다.
//  (그 시간대 안에서 보면 위의 첫 경로로 언제나 맞다.)
//  완전한 해결은 기록 당시의 달력 날짜를 따로 저장하는 것(SchemaV3 `dayKey`, dev.md 2.3).
//

import Foundation

nonisolated struct DayKey: Hashable, Comparable, Sendable, CustomStringConvertible {

    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// 달력 위의 한 날(화면의 칸 · 오늘). `calendar`의 시간대로 읽는다.
    init(_ date: Date, calendar: Calendar = .current) {
        let parts = Self.gregorian(in: calendar.timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// 저장된 기록의 날. `midnight`는 기록할 때 기기 시간대의 자정이다.
    init(recordedMidnight midnight: Date, calendar: Calendar = .current) {
        // 지금 시간대에서 남긴 기록(대부분): 그 시간대의 자정과 정확히 같다.
        if calendar.startOfDay(for: midnight) == midnight {
            self.init(midnight, calendar: calendar)
            return
        }
        // 다른 시간대에서 남긴 기록: 이 시각이 '자정'이 될 수 있는 날을 찾는다.
        let utc = Self.gregorian(in: .gmt)
        var found: DayKey?
        var cursor = utc.startOfDay(for: midnight.addingTimeInterval(TimeInterval(Self.minimumOffset)))
        let last = midnight.addingTimeInterval(TimeInterval(Self.maximumOffset))
        while cursor <= last {
            // t = D 00:00Z − offset  →  offset = D 00:00Z − t
            let offset = Int(cursor.timeIntervalSince(midnight).rounded())
            if (Self.minimumOffset..<Self.maximumOffset).contains(offset) {
                found = DayKey(cursor, calendar: utc)
                break
            }
            cursor = utc.date(byAdding: .day, value: 1, to: cursor) ?? last.addingTimeInterval(1)
        }
        // 24시간 폭이라 언제나 하나가 나온다. 만일을 위해 지금 시간대의 그날로 물러선다.
        self = found ?? DayKey(midnight, calendar: calendar)
    }

    /// 기록한 곳으로 볼 오프셋 범위 [UTC−10, UTC+14) — 답이 하나로 정해지는 24시간 폭.
    static let minimumOffset = -10 * 3600
    static let maximumOffset = 14 * 3600

    /// 이 날의 자정(`calendar`의 시간대). 그 시간대에 자정이 없는 날이면 그날의 첫 시각.
    func startOfDay(in calendar: Calendar = .current) -> Date {
        let gregorian = Self.gregorian(in: calendar.timeZone)
        let noon = gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        return gregorian.startOfDay(for: noon)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// 열쇠는 언제나 그레고리력. 사용자가 다른 달력을 써도 같은 날은 같은 열쇠다.
    private static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
