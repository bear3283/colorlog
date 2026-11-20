//
//  NotificationRouter.swift
//  colorlog
//
//  알림을 눌러서 들어온 사용자를 곧장 '그 알림이 물어본 하루 한 장'으로 데려다 놓는다.
//
//  알림만 띄우고 앱은 그냥 열리게 두면, 사용자는 질문을 받고 들어와서
//  다시 오늘 칸을 찾아 눌러야 한다. 물어본 쪽이 답할 자리를 열어 줘야 한다.
//  그래서 알림이 울린 날의 시트를 열고, 알림이 물어본 자리(아침 · 점심 · 저녁)를 골라 둔다.
//

import SwiftUI
import Observation
import UserNotifications

/// 알림 하나가 열어 달라고 하는 곳. 날과 자리.
nonisolated struct NotificationOpenRequest: Equatable, Sendable {

    /// 알림 `userInfo`에서 자리를 담는 키. 예약하는 쪽(`ReminderStore`)과 같은 값을 쓴다.
    static let slotKey = "slot"

    /// 열어야 할 날(그 날의 자정).
    let day: Date
    /// 골라 둘 자리. 알 수 없으면 nil — 시트가 평소처럼 밀린 자리를 고른다.
    let slot: DailyColorLog.Slot?

    init(day: Date, slot: DailyColorLog.Slot?) {
        self.day = day
        self.slot = slot
    }

    /// 알림 응답을 풀어 낸다.
    ///
    /// - 날: 알림이 **울린** 날. 아침 알림을 다음 날 눌러도 질문받은 그날을 연다.
    ///   (시계가 돌아가 울린 시각이 지금보다 뒤라면 오늘로 맞춘다 — 미래 칸은 열 수 없다.)
    /// - 자리: `userInfo["slot"]`. 없거나 모르는 값(다음 버전이 보낸 자리 등)이면 nil.
    static func parse(
        userInfo: [AnyHashable: Any],
        deliveredAt: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> NotificationOpenRequest {
        let slot = (userInfo[slotKey] as? String).flatMap(DailyColorLog.Slot.init(rawValue:))
        let day = calendar.startOfDay(for: min(deliveredAt, now))
        return NotificationOpenRequest(day: day, slot: slot)
    }
}

@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// 열어야 할 하루. 뷰가 처리한 뒤 nil로 되돌린다.
    var request: NotificationOpenRequest?

    private init() {}

    func open(_ request: NotificationOpenRequest) {
        self.request = request
    }
}

/// `UNUserNotificationCenter`의 delegate는 앱이 실행을 마치기 *전에* 지정돼야 한다.
/// (콜드 런치로 알림을 눌러 들어온 경우, 늦게 지정하면 응답을 놓친다)
/// 그래서 SwiftUI의 `.task`가 아니라 AppDelegate가 필요하다.
final class ColorLogAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// 앱을 켜 둔 채 알림 시각이 됐을 때도 배너를 띄운다.
    /// 화면을 보고 있다고 해서 질문을 건너뛸 이유는 없다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // 지우기 같은 다른 동작은 앱을 열지 않는다. 기본 탭만 하루 한 장으로 잇는다.
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let notification = response.notification
        let request = NotificationOpenRequest.parse(
            userInfo: notification.request.content.userInfo,
            deliveredAt: notification.date
        )
        await MainActor.run {
            NotificationRouter.shared.open(request)
        }
    }
}
