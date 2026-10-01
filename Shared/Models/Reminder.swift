//
//  Reminder.swift
//  colorlog (앱 · 위젯 공용)
//
//  "몇 시에 물어볼지"의 설정값.
//
//  앱에서만 쓰던 것을 공용으로 옮겼다. 라이브 액티비티가 '지난 슬롯인데 아직
//  기록이 없는지'를 판단하려면 사용자가 정한 시각을 알아야 하는데,
//  그 판단이 App Intent(위젯 프로세스)에서도 일어나기 때문이다.
//

import Foundation

nonisolated struct Reminder: Identifiable, Equatable, Codable, Sendable {

    var slot: DailyColorLog.Slot
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    var id: String { "colorlog.reminder.\(slot.rawValue)" }

    /// `DatePicker`와 주고받기 위한 변환. 날짜 부분은 의미가 없다.
    var time: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    mutating func setTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? hour
        minute = components.minute ?? minute
    }

    /// 오늘의 이 시각. 지났는지 판단하고 알림을 거는 데 함께 쓴다.
    func triggerDate(on day: Date = .now, calendar: Calendar = .current) -> Date? {
        calendar.date(
            bySettingHour: hour, minute: minute, second: 0,
            of: calendar.startOfDay(for: day)
        )
    }

    static func defaults() -> [Reminder] {
        DailyColorLog.Slot.allCases.map {
            Reminder(slot: $0, isEnabled: true, hour: $0.defaultHour, minute: 0)
        }
    }
}

// MARK: - 저장 (App Group)

nonisolated extension Reminder {

    private static let storageKey = "colorlog.reminders"

    /// 슬롯이 나중에 늘어나도 저장본이 이를 덮어쓰지 않도록 병합해서 읽는다.
    static func load() -> [Reminder] {
        guard let data = ColorLogStore.defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data),
              !decoded.isEmpty else {
            return defaults()
        }
        return DailyColorLog.Slot.allCases.map { slot in
            decoded.first { $0.slot == slot }
                ?? Reminder(slot: slot, isEnabled: true, hour: slot.defaultHour, minute: 0)
        }
    }

    static func save(_ reminders: [Reminder]) {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        ColorLogStore.defaults.set(data, forKey: storageKey)
    }

    /// 그날 이미 물어본 자리들. 물어본 시각 순서. 꺼 둔 자리는 빠진다.
    static func dueSlots(at date: Date = .now, reminders: [Reminder]? = nil) -> [DailyColorLog.Slot] {
        (reminders ?? load())
            .filter(\.isEnabled)
            .compactMap { reminder in
                reminder.triggerDate(on: date).map { (reminder.slot, $0) }
            }
            .filter { $0.1 <= date }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}
