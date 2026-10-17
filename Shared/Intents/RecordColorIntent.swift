//
//  RecordColorIntent.swift
//  colorlog (앱 · 위젯 공용)
//
//  위젯에 펼쳐진 색 하나를 누르면 실행되는 동작.
//
//  이 인텐트가 실행되는 프로세스는 앱일 수도, 위젯 익스텐션일 수도 있다.
//  그래서 앱의 뷰 상태에 기대지 않고 **공유 저장소에만** 쓴다.
//  앱을 열지 않고도 기록이 끝나는 것이 이 기능의 전부다.
//

import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct RecordColorIntent: AppIntent {

    static let title: LocalizedStringResource = "색 기록하기"
    static let description = IntentDescription("오늘의 분위기를 색 하나로 남깁니다.")
    /// 앱을 열지 않고 백그라운드에서 끝낸다.
    static let openAppWhenRun = false

    @Parameter(title: "색") var hex: String
    /// `DailyColorLog.Slot.rawValue`. 위젯이 '방금 물어본 자리'를 정해서 넘긴다.
    @Parameter(title: "자리") var slot: String

    init() {}

    init(hex: String, slot: DailyColorLog.Slot) {
        self.hex = hex
        self.slot = slot.rawValue
    }

    func perform() async throws -> some IntentResult {
        let palette = Palette.current

        guard let target = DailyColorLog.Slot(rawValue: slot) else { return .result() }

        let context = ModelContext(ColorLogStore.shared)
        // 다른 자리는 건드리지 않는다. HEX가 잘못됐으면 아무 일도 없다.
        _ = try context.setColor(hex, for: target, palette: palette)

        // 위젯이 고르는 얼굴에서 칠해진 얼굴로 넘어간다.
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
