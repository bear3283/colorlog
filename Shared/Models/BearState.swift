//
//  BearState.swift
//  colorlog (앱 · 위젯 공용)
//
//  하루 칸에 어떤 곰이, 어떤 모습으로 앉을지.
//
//  상태는 따로 저장하지 않는다. 그날 채운 자리 수에서 매번 계산한다.
//  상태를 저장해 두면 기록을 지우거나 고쳤을 때 둘이 어긋난다.
//
//  곰의 동작은 상태가 아니라 **기록**이 정한다. 처음 기록될 때 스무 가지 중 하나가
//  무작위로 저장되고(`DailyColorLog.poseRawValue`), 사용자가 칸을 길게 눌러 바꿀 수 있다.
//  동작이 저장되기 전의 기록은 날짜 시드로 뽑는다 — 그릴 때마다 새로 뽑으면
//  스크롤할 때마다 곰이 바뀐다.
//  색과 동작을 묶지 않은 건, 팔레트의 색에 감정 이름이 없기 때문이다. 색의 뜻은
//  사용자가 정하고, 앱이 '이 색이면 화난 곰'이라고 읽어 주지 않는다.
//
//  상태가 동작을 정하는 건 세 곳뿐이다.
//   · 아직 아무것도 칠하지 않은 오늘 — 시무룩하게 앉아 첫 색을 기다린다.
//   · 세 자리를 다 채운 순간의 달성 팝업 — 만세.
//   · 위젯이 쉬고 있을 때 — 잔다.
//

import Foundation

/// 하루 기록의 진행 상태.
enum BearState: Equatable {
    /// 아직 한 자리도 채우지 않았다.
    case empty
    /// 한두 자리를 채웠다.
    case recording
    /// 세 자리를 다 채웠다.
    case completed
    /// 위젯처럼 물어볼 차례가 아닌 곳에서 쉬고 있다.
    case sleeping

    init(filledCount: Int) {
        switch filledCount {
        case ..<1: self = .empty
        case ..<DailyColorLog.maxColorsPerDay: self = .recording
        default: self = .completed
        }
    }

    init(log: DailyColorLog?) {
        self.init(filledCount: log?.filledCount ?? 0)
    }

    /// 이 상태가 직접 정하는 동작. 기록 중인 날은 날짜가 정하므로 nil.
    var pose: BearPose? {
        switch self {
        case .empty: .sitting
        case .recording: nil
        case .completed: .cheering
        case .sleeping: .sleeping
        }
    }
}

/// 하루 칸 하나에 그릴 곰.
struct DayBear: Equatable {

    enum Style: Equatable {
        /// 옅은 회색 선화. 아직 오지 않은 날, 그리고 아무것도 남기지 않고 지나간 날.
        case lineArt
        /// 선과 종이만. 오늘 아직 칠하지 않은 곰.
        case bare
        /// 그날 고른 색으로 칠한 곰.
        case painted
    }

    let pose: BearPose
    let style: Style

    /// 그날의 날짜 · 칠한 자리 수 · 오늘과의 관계로 곰을 고른다.
    /// 칠한 날의 동작은 기록에 저장된 것(`storedPose`)을 쓰고, 없으면 날짜 시드로 고른다.
    ///
    /// 아무것도 남기지 않고 지나간 날을 시무룩한 곰으로 그리지 않는다. 빈 날마다
    /// 시무룩한 곰이 쌓이면 밀린 숙제처럼 읽힌다. 미래와 같은 옅은 선화로 둔다.
    init(date: Date, filledCount: Int, relation: DayRelation, storedPose: BearPose? = nil) {
        switch (relation, filledCount) {
        case (.future, _):
            self.init(pose: .standing, style: .lineArt)
        case (.today, ..<1):
            self.init(pose: BearState.empty.pose ?? .sitting, style: .bare)
        case (.past, ..<1):
            self.init(pose: .standing, style: .lineArt)
        default:
            self.init(pose: storedPose ?? .random(for: date), style: .painted)
        }
    }

    init(pose: BearPose, style: Style) {
        self.pose = pose
        self.style = style
    }
}

extension DailyColorLog {
    /// 그날 곰의 동작. nil이면 동작이 저장되기 전의 기록.
    var pose: BearPose? {
        get { poseRawValue.flatMap(BearPose.init(rawValue:)) }
        set { poseRawValue = newValue?.rawValue }
    }
}

extension BearPose {

    /// 날짜로 고정한 무작위 동작. 스무 가지 모두가 후보다.
    ///
    /// `colorSeed`를 그대로 나머지 연산하면 날마다 같은 간격으로 건너뛰어 무늬가
    /// 보인다. 시드 생성기를 한 번 거쳐 이웃한 날끼리도 고르게 흩어지게 한다.
    static func random(for date: Date) -> BearPose {
        var rng = SeededGenerator(seed: Calendar.current.startOfDay(for: date).colorSeed ^ 0xBEA2_D0CE)
        return allCases.randomElement(using: &rng) ?? .standing
    }
}
