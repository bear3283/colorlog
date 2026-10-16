//
//  DailyColorLog.swift
//  colorlog
//
//  하루 = 레코드 1개. 그 안에 아침·점심·저녁 세 **자리**가 있다.
//
//  ⚠️ 가장 중요한 불변식: `date`는 언제나 자정(startOfDay)으로 정규화된다.
//     타임라인 그리드는 "날짜 → 로그" 딕셔너리 O(1) 조회에 의존하므로
//     시각(time) 성분이 한 번이라도 섞이면 같은 날이 두 칸으로 쪼개진다.
//     그래서 `date`는 private(set)이고, 반드시 이니셜라이저/`move(to:)`로만 바뀐다.
//
//  자리 고정:
//  예전에는 `colors`가 기록한 순서대로 쌓이는 빈틈 없는 배열이었다. 그래서 점심 색을
//  지우면 저녁 색이 점심 자리로 당겨졌고, '점심만 바꾸기'가 불가능했다.
//  지금은 index 0·1·2가 곧 아침·점심·저녁이고, 빈 자리는 빈 문자열("")로 남는다.
//
//  저장 형태(`[String]`)는 그대로라 스키마 마이그레이션이 없다. 예전 기록은
//  들어온 순서대로 아침 → 점심 → 저녁 자리에 놓인 것으로 읽힌다.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class DailyColorLog {

    /// 하루당 레코드는 반드시 하나. SwiftData가 중복 insert를 upsert로 처리해 주므로
    /// 알림/위젯 같은 여러 진입점에서 동시에 써도 날짜가 갈라지지 않는다.
    #Unique<DailyColorLog>([\.date])
    /// 타임라인은 항상 기간 범위로 훑기 때문에 날짜 인덱스가 곧 스크롤 성능이다.
    #Index<DailyColorLog>([\.date])

    /// 기록된 날의 자정(로컬 타임존 기준).
    private(set) var date: Date

    /// 자리별 HEX. index = `Slot`의 순서, 빈 자리는 "".
    /// 예전 기록은 3개보다 짧을 수 있다 — 읽을 때는 반드시 `slotColors`를 거친다.
    private(set) var colors: [String]

    /// 기록 당시 적용돼 있던 팔레트의 `ColorPalette.rawValue`.
    /// 나중에 사용자가 테마를 바꿔도 "그날의 색이 어떤 세계관에서 골라졌는지"는 보존된다.
    var themePalette: String

    /// 그날 곰의 동작(`BearPose.rawValue`).
    ///
    /// 처음 기록될 때 무작위로 정해지고, 사용자가 칸을 길게 눌러 바꿀 수 있다.
    /// 색에 감정 이름이 없듯 동작도 앱이 정해 주지 않는다 — 고른 색이 무슨 기분인지는
    /// 사용자만 안다. 그래서 처음엔 아무 곰이나 앉히고, 바꾸는 건 사용자에게 맡긴다.
    ///
    /// 선택값이라 기존 저장소는 마이그레이션 없이 열린다. nil은 이 속성이 생기기 전의
    /// 기록이고, 그동안 보여 주던 날짜 시드 동작을 그대로 쓴다.
    var poseRawValue: String?

    /// 하루의 자리 수 (아침·점심·저녁).
    static let maxColorsPerDay = 3

    /// - Parameter colors: 자리 순서의 HEX. ""는 빈 자리.
    init(date: Date = .now, colors: [String] = [], palette: ColorPalette = .default) {
        self.date = Calendar.current.startOfDay(for: date)
        self.colors = Self.sanitize(colors)
        self.themePalette = palette.rawValue
        self.poseRawValue = BearPose.allCases.randomElement()?.rawValue
    }

    /// 잘못된 HEX는 빈 자리로, 나머지는 정규형으로. 언제나 세 자리.
    private static func sanitize(_ raw: [String]) -> [String] {
        (0..<maxColorsPerDay).map { index in
            raw.indices.contains(index) ? (HexColor.normalized(raw[index]) ?? "") : ""
        }
    }
}

// MARK: - 파생 값

extension DailyColorLog {

    /// 이 로그가 기록될 당시의 팔레트.
    var palette: ColorPalette {
        get { ColorPalette(storedValue: themePalette) }
        set { themePalette = newValue.rawValue }
    }

    /// 언제나 세 칸. 빈 자리는 "". 화면은 전부 이걸 읽는다.
    var slotColors: [String] { Self.sanitize(colors) }

    func color(for slot: Slot) -> String? {
        let hex = slotColors[slot.index]
        return hex.isEmpty ? nil : hex
    }

    var filledCount: Int { slotColors.count { !$0.isEmpty } }
    var isEmpty: Bool { filledCount == 0 }
    var isFull: Bool { filledCount >= Self.maxColorsPerDay }
}

// MARK: - 기록 동작

extension DailyColorLog {

    /// 한 자리에 색을 넣거나(교체 포함) 비운다. 다른 자리는 움직이지 않는다.
    /// - Parameter hex: nil이면 그 자리를 비운다.
    /// - Returns: 실제로 바뀌었는지. (잘못된 HEX면 `false`)
    @discardableResult
    func setColor(_ hex: String?, for slot: Slot) -> Bool {
        var slots = slotColors
        if let hex {
            guard let normalized = HexColor.normalized(hex) else { return false }
            slots[slot.index] = normalized
        } else {
            slots[slot.index] = ""
        }
        colors = slots
        return true
    }

    /// 날짜 이동이 필요한 경우(예: 자정 직후 기록을 전날로 귀속)에만 사용.
    /// 정규화를 우회할 수 없도록 유일한 통로로 열어 둔다.
    func move(to newDate: Date) {
        date = Calendar.current.startOfDay(for: newDate)
    }
}

// MARK: - 하루 안의 시간대

extension DailyColorLog {

    /// 하루의 세 자리. 알림을 띄우는 시점이자 `colors`의 index.
    nonisolated enum Slot: String, CaseIterable, Identifiable, Codable, Sendable {
        case morning, afternoon, evening

        var id: String { rawValue }

        /// `colors` 안에서의 위치.
        var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

        /// 칸을 열었을 때 처음 골라 둘 자리.
        ///
        /// 1) 이미 지나간(물어본) 자리 중 비어 있는 첫 자리 — 밀린 걸 먼저
        /// 2) 그게 없으면 아직 오지 않은 자리 중 빈 첫 자리 — 다음 차례
        /// 3) 다 찼으면 가장 최근에 물어본 자리 — 바꾸고 싶은 건 대개 방금 고른 색이다
        static func defaultSelection(slotColors: [String], due: [Slot]) -> Slot {
            let isEmpty: (Slot) -> Bool = { slotColors.indices.contains($0.index) ? slotColors[$0.index].isEmpty : true }
            return due.first(where: isEmpty)
                ?? allCases.first(where: isEmpty)
                ?? due.last
                ?? .morning
        }

        /// VoiceOver와 알림에서만 쓰인다. 화면에는 심볼이 대신 선다.
        var displayName: String {
            switch self {
            case .morning:   "아침"
            case .afternoon: "점심"
            case .evening:   "저녁"
            }
        }

        /// 글자 대신 이 시간대를 가리키는 그림.
        var symbolName: String {
            switch self {
            case .morning:   "sunrise.fill"
            case .afternoon: "sun.max.fill"
            case .evening:   "moon.fill"
            }
        }

        /// 알림 본문에서만 쓰인다. 앱 화면에는 어떤 문장도 올리지 않는다.
        var prompt: String {
            switch self {
            case .morning:   "지금, 어떤 색인가요"
            case .afternoon: "지금, 어떤 색인가요"
            case .evening:   "오늘을 덮을 색"
            }
        }

        /// 기본 알림 시각(로컬). 08:00 / 13:00 / 21:00
        var defaultHour: Int {
            switch self {
            case .morning:   8
            case .afternoon: 13
            case .evening:   21
            }
        }
    }
}

// MARK: - 조회 헬퍼

extension DailyColorLog {

    /// `#Predicate` 안에서는 `Calendar` 연산을 쓸 수 없다.
    /// 경계 계산은 반드시 바깥에서 끝내고 상수만 넘긴다.
    static func predicate(from start: Date, until end: Date) -> Predicate<DailyColorLog> {
        #Predicate { $0.date >= start && $0.date < end }
    }

    /// 하루치.
    static func predicate(for day: Date, calendar: Calendar = .current) -> Predicate<DailyColorLog> {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return predicate(from: start, until: end)
    }

    /// 타임라인이 화면에 보이는 구간만 끊어 읽을 때 쓰는 디스크립터.
    /// - Parameters:
    ///   - start: 포함(inclusive)
    ///   - end: 미포함(exclusive)
    static func descriptor(from start: Date, until end: Date) -> FetchDescriptor<DailyColorLog> {
        FetchDescriptor(
            predicate: predicate(from: start, until: end),
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
    }
}
