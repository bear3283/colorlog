//
//  NotificationRoutingTests.swift
//  colorlogTests
//
//  알림을 누르면 '그 알림이 물어본 날 · 자리'의 하루 한 장이 열려야 한다.
//  userInfo를 잘못 풀면 엉뚱한 날이 열리거나, 다음 버전이 보낸 값에 앱이 넘어진다.
//

import Foundation
import Testing
@testable import colorlog

struct NotificationRoutingTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("예약할 때 넣은 자리가 그대로 돌아온다", arguments: DailyColorLog.Slot.allCases)
    func slotRoundTrip(slot: DailyColorLog.Slot) {
        // ReminderStore가 거는 userInfo 모양 그대로.
        let userInfo: [AnyHashable: Any] = [NotificationOpenRequest.slotKey: slot.rawValue]
        let delivered = Self.date(2026, 11, 21, slot.defaultHour)
        let request = NotificationOpenRequest.parse(
            userInfo: userInfo, deliveredAt: delivered, now: delivered.addingTimeInterval(60), calendar: Self.calendar)
        #expect(request.slot == slot)
        #expect(request.day == Self.date(2026, 11, 21, 0))
    }

    /// 알 수 없는 userInfo 모양들. (AnyHashable은 Sendable이 아니라 인자로 직접 넘기지 않는다)
    enum Payload: CaseIterable, Sendable {
        case empty, unknownSlot, blank, number, wrongCase, otherKey

        var userInfo: [AnyHashable: Any] {
            switch self {
            case .empty: [:]
            case .unknownSlot: ["slot": "midnight"]
            case .blank: ["slot": ""]
            case .number: ["slot": 1]
            case .wrongCase: ["slot": "Morning"]
            case .otherKey: ["other": "morning"]
            }
        }
    }

    @Test("자리가 없거나 모르는 값이면 nil — 시트가 밀린 자리를 고른다", arguments: Payload.allCases)
    func unknownSlot(payload: Payload) {
        let delivered = Self.date(2026, 11, 21, 13)
        let request = NotificationOpenRequest.parse(
            userInfo: payload.userInfo, deliveredAt: delivered, now: delivered, calendar: Self.calendar)
        #expect(request.slot == nil)
        #expect(request.day == Self.date(2026, 11, 21, 0))
    }

    @Test("저녁 알림을 다음 날 아침에 눌러도 질문받은 날(울린 날)을 연다")
    func tappedNextDay() {
        let delivered = Self.date(2026, 11, 20, 21)
        let now = Self.date(2026, 11, 21, 7, 30)
        let request = NotificationOpenRequest.parse(
            userInfo: ["slot": "evening"], deliveredAt: delivered, now: now, calendar: Self.calendar)
        #expect(request.day == Self.date(2026, 11, 20, 0))
        #expect(request.slot == .evening)
    }

    @Test("자정 직전에 울린 알림은 그날, 자정 직후는 다음 날")
    func midnightBoundary() {
        let beforeMidnight = Self.calendar.date(byAdding: .second, value: -1, to: Self.date(2026, 11, 21, 0))!
        let afterMidnight = Self.date(2026, 11, 21, 0)
        let now = Self.date(2026, 11, 21, 9)
        #expect(NotificationOpenRequest.parse(
            userInfo: [:], deliveredAt: beforeMidnight, now: now, calendar: Self.calendar).day
            == Self.date(2026, 11, 20, 0))
        #expect(NotificationOpenRequest.parse(
            userInfo: [:], deliveredAt: afterMidnight, now: now, calendar: Self.calendar).day
            == Self.date(2026, 11, 21, 0))
    }

    @Test("울린 시각이 지금보다 뒤(시계가 되돌아감)면 오늘로 — 미래 칸은 열지 않는다")
    func deliveredInFuture() {
        let now = Self.date(2026, 11, 21, 9)
        let delivered = Self.date(2026, 11, 22, 8)
        let request = NotificationOpenRequest.parse(
            userInfo: ["slot": "morning"], deliveredAt: delivered, now: now, calendar: Self.calendar)
        #expect(request.day == Self.date(2026, 11, 21, 0))
    }
}
