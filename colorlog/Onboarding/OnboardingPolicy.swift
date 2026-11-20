//
//  OnboardingPolicy.swift
//  colorlog
//
//  첫 실행 안내(곰 세 장)를 보여 줄지.
//
//  · 처음 설치한 사람에게만 한 번 보여 준다.
//  · 이미 색을 남긴 사람(1.0 · 1.1에서 올라온 사용자)에게는 강제로 띄우지 않는다.
//    그들에게 "하루 세 번 색을 골라요"는 이미 아는 이야기이고, 쌓인 곰 앞을 막아서면 안 된다.
//    한 번 건너뛴 걸로 적어 둔다 — 나중에 기록을 모두 비워도 다시 뜨지 않는다.
//
//  표시 여부는 SwiftData 모델을 건드리지 않고 App Group 설정값 하나로만 기억한다.
//

import Foundation
import SwiftData

nonisolated enum OnboardingPolicy {

    /// 안내를 끝냈거나(또는 기존 사용자라 건너뛰었거나) 했는지. App Group 설정.
    static let completedKey = "colorlog.onboarding.completed"

    enum Decision: Equatable {
        /// 처음 온 사람. 안내를 보여 준다.
        case show
        /// 이미 기록이 있는 사람. 보여 주지 않고, 끝낸 것으로 적어 둔다.
        case skipExistingUser
        /// 이미 끝냈다.
        case alreadyCompleted
    }

    /// 순수 판단. 끝낸 표시가 가장 먼저, 그다음 기록 유무.
    static func decide(isCompleted: Bool, recordCount: Int) -> Decision {
        if isCompleted { return .alreadyCompleted }
        if recordCount > 0 { return .skipExistingUser }
        return .show
    }

    /// 저장소와 설정을 읽어 판단하고, 기존 사용자면 끝낸 것으로 적는다.
    /// 기록 수를 세지 못하면(저장소 오류) 안내를 띄우지 않는다 — 기존 사용자를 막아서는 쪽이 더 나쁘다.
    @MainActor
    static func evaluate(context: ModelContext, defaults: UserDefaults = ColorLogStore.defaults) -> Decision {
        let isCompleted = defaults.bool(forKey: completedKey)
        if isCompleted { return .alreadyCompleted }

        let count: Int
        do {
            count = try context.fetchCount(FetchDescriptor<DailyColorLog>())
        } catch {
            return .alreadyCompleted
        }

        let decision = decide(isCompleted: false, recordCount: count)
        if decision == .skipExistingUser {
            markCompleted(defaults: defaults)
        }
        return decision
    }

    static func markCompleted(defaults: UserDefaults = ColorLogStore.defaults) {
        defaults.set(true, forKey: completedKey)
    }
}
