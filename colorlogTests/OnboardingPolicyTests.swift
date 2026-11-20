//
//  OnboardingPolicyTests.swift
//  colorlogTests
//
//  첫 실행 안내는 처음 온 사람에게만. 이미 곰을 쌓은 사람 앞을 막아서면 안 된다.
//

import Foundation
import SwiftData
import Testing
@testable import colorlog

@MainActor
struct OnboardingPolicyTests {

    /// 테스트마다 따로 쓰는 설정 저장소. 실제 App Group 값은 건드리지 않는다.
    private static func scratchDefaults() -> UserDefaults {
        let name = "colorlog.tests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("판단표", arguments: [
        (false, 0, OnboardingPolicy.Decision.show),
        (false, 1, .skipExistingUser),
        (false, 400, .skipExistingUser),
        (true, 0, .alreadyCompleted),
        (true, 12, .alreadyCompleted),
    ])
    func decisionTable(isCompleted: Bool, recordCount: Int, expected: OnboardingPolicy.Decision) {
        #expect(OnboardingPolicy.decide(isCompleted: isCompleted, recordCount: recordCount) == expected)
    }

    @Test("새로 설치: 기록도 끝낸 표시도 없으면 보여 주고, 아직 끝낸 걸로 적지 않는다")
    func freshInstall() {
        let defaults = Self.scratchDefaults()
        let container = ColorLogStore.inMemory()
        #expect(OnboardingPolicy.evaluate(context: container.mainContext, defaults: defaults) == .show)
        #expect(defaults.bool(forKey: OnboardingPolicy.completedKey) == false)
    }

    @Test("기존 사용자: 기록이 있으면 띄우지 않고 끝낸 걸로 적는다 — 기록을 비워도 다시 뜨지 않는다")
    func existingUser() throws {
        let defaults = Self.scratchDefaults()
        let container = ColorLogStore.inMemory()
        let context = container.mainContext
        let palette = Palette.default
        _ = try context.setColor(palette.swatches[0].hex, for: .morning, on: .now, palette: palette)

        #expect(OnboardingPolicy.evaluate(context: context, defaults: defaults) == .skipExistingUser)
        #expect(defaults.bool(forKey: OnboardingPolicy.completedKey))

        // 색을 지워도(빈 기록이 남거나 기록이 없어져도) 안내는 다시 오지 않는다.
        _ = try context.setColor(nil, for: .morning, on: .now, palette: palette)
        for log in try context.fetch(FetchDescriptor<DailyColorLog>()) { context.delete(log) }
        try context.save()
        #expect(OnboardingPolicy.evaluate(context: context, defaults: defaults) == .alreadyCompleted)
    }

    @Test("안내를 끝내면 다음 실행부터는 보이지 않는다")
    func completedOnce() {
        let defaults = Self.scratchDefaults()
        let container = ColorLogStore.inMemory()
        #expect(OnboardingPolicy.evaluate(context: container.mainContext, defaults: defaults) == .show)
        OnboardingPolicy.markCompleted(defaults: defaults)
        #expect(OnboardingPolicy.evaluate(context: container.mainContext, defaults: defaults) == .alreadyCompleted)
    }

    @Test("색을 모두 지운 빈 레코드만 남아 있어도 기존 사용자로 본다")
    func emptyRecordStillCounts() throws {
        let defaults = Self.scratchDefaults()
        let container = ColorLogStore.inMemory()
        let context = container.mainContext
        context.insert(DailyColorLog(date: .now, colors: ["", "", ""], palette: .default))
        try context.save()
        #expect(OnboardingPolicy.evaluate(context: context, defaults: defaults) == .skipExistingUser)
    }
}
