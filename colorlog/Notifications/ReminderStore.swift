//
//  ReminderStore.swift
//  colorlog
//
//  하루 세 번, 색을 물어보는 알림.
//
//  기본값은 08:00 / 13:00 / 21:00 이고 슬롯마다 켜고 끄거나 시간을 옮길 수 있다.
//  `UNCalendarNotificationTrigger(repeats: true)`로 슬롯당 요청 하나만 유지한다 —
//  매일 새로 예약하는 방식은 앱을 며칠 안 열면 알림이 끊긴다.
//

import Foundation
import Observation
import OSLog
import UserNotifications
import WidgetKit

nonisolated private let logger = Logger(subsystem: "com.colorlog", category: "reminders")

@MainActor
@Observable
final class ReminderStore {

    static let shared = ReminderStore()

    private(set) var reminders: [Reminder]
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    /// 알림을 실제로 보낼 수 있는 상태인가.
    var isAuthorized: Bool {
        authorization == .authorized || authorization == .provisional || authorization == .ephemeral
    }

    private init() {
        reminders = Reminder.load()
    }

    // MARK: 권한

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshAuthorization()
        await reschedule()
        return granted
    }

    // MARK: 변경

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.slot == reminder.slot }) else { return }
        guard reminders[index] != reminder else { return }
        reminders[index] = reminder
        persist()
        Task { await reschedule() }
    }

    /// 시각 설정이 바뀌면 '밀린 슬롯' 계산도 달라진다.
    var current: [Reminder] { reminders }

    func setAllEnabled(_ isEnabled: Bool) {
        for index in reminders.indices {
            reminders[index].isEnabled = isEnabled
        }
        persist()
        Task { await reschedule() }
    }

    private func persist() {
        Reminder.save(reminders)
        // 위젯은 이 시각들에 맞춰 '고르는 얼굴'로 바뀐다. 시각이 옮겨 가면
        // 이미 짜 둔 타임라인이 어긋나므로 다시 짜게 한다.
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: 예약

    /// 예약을 통째로 지우고 다시 건다.
    /// 시간만 바꾼 요청을 덮어쓰려 해도 식별자가 같으면 갱신되지만,
    /// 껐다 켠 슬롯이 남는 걸 막으려면 지우고 다시 거는 쪽이 상태가 단순하다.
    func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reminders.map(\.id))

        guard isAuthorized else { return }

        for reminder in reminders where reminder.isEnabled {
            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute

            let content = UNMutableNotificationContent()
            content.title = "컬러로그"
            content.body = reminder.slot.prompt
            content.sound = .default
            content.userInfo = ["slot": reminder.slot.rawValue]

            let request = UNNotificationRequest(
                identifier: reminder.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            do {
                try await center.add(request)
            } catch {
                // 여기서 실패하는 가장 흔한 이유는 '사용자가 방금 알림을 껐다'는
                // 지극히 정상적인 상태다(UNErrorDomain 2003).
                // 위에서 권한을 확인해도 그 사이에 iOS 설정에서 꺼 버리는 경로가 남아 있다.
                // 프로그래밍 오류가 아니므로 절대 크래시시키지 않는다.
                logger.warning("알림 예약 실패(\(reminder.slot.rawValue, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// 예약이 실제로 걸려 있는지. (설정 화면의 상태 표시·디버깅용)
    func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }
}
