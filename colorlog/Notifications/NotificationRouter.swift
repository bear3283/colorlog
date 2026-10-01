//
//  NotificationRouter.swift
//  colorlog
//
//  알림을 눌러서 들어온 사용자를 곧장 '오늘 칸이 열린 상태'로 데려다 놓는다.
//
//  알림만 띄우고 앱은 그냥 열리게 두면, 사용자는 질문을 받고 들어와서
//  다시 오늘 칸을 찾아 눌러야 한다. 물어본 쪽이 답할 자리를 열어 줘야 한다.
//

import SwiftUI
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// 열어야 할 날. 뷰가 처리한 뒤 nil로 되돌린다.
    var requestedDate: Date?

    private init() {}

    func requestOpen(on date: Date = .now) {
        requestedDate = Calendar.current.startOfDay(for: date)
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
        await MainActor.run {
            NotificationRouter.shared.requestOpen()
        }
    }
}
