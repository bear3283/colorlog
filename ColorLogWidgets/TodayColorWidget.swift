//
//  TodayColorWidget.swift
//  ColorLogWidgets
//
//  홈 화면의 오늘 한 칸. 그림은 `TodayColorView`(공용)가 그리고,
//  여기서는 '언제 어떤 얼굴이어야 하는지'를 타임라인으로 짠다.
//
//  하루의 흐름:
//    자정 ─ 빈 색
//    첫 번째 물어보는 시각 ─ 색 다섯이 둘러선다 → 하나 고르면 그 색으로 칠해진다
//    두 번째 시각 ─ 다시 다섯 → 고르면 두 색으로
//    세 번째 시각 ─ 다시 다섯 → 고르면 세 색으로
//
//  물어보는 시각마다 엔트리를 하나씩 미리 넣어 두므로, 앱이 깨어 있지 않아도
//  그 시각이 되면 위젯이 스스로 고르는 얼굴로 바뀐다. 고른 직후의 변화는
//  `RecordColorIntent`가 타임라인을 다시 짜게 해서 반영한다.
//

import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Entry

struct TodayColorEntry: TimelineEntry {
    let date: Date
    let palette: ColorPalette
    /// 자리별 색. ""는 빈 자리.
    let colors: [String]
    /// 이 시각에 물어보는 자리. nil이면 칠해진 얼굴.
    let target: DailyColorLog.Slot?
    /// 오늘 기록에 저장된 곰의 동작.
    var pose: BearPose? = nil
}

// MARK: - Provider

struct TodayColorProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayColorEntry {
        TodayColorEntry(date: .now, palette: .default, colors: [], target: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayColorEntry) -> Void) {
        if context.isPreview {
            // 위젯 갤러리에서는 이 위젯이 '하는 일'을 보여 준다 — 아침 색을 고른 뒤
            // 점심 시각이 되어 다시 색이 둘러선 모습.
            let palette = currentPalette()
            completion(TodayColorEntry(
                date: .now, palette: palette,
                colors: [palette.swatches[1].hex, "", ""], target: .afternoon
            ))
        } else {
            let today = todaysLog()
            completion(entry(at: .now, colors: today.colors, pose: today.pose, reminders: Reminder.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayColorEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let reminders = Reminder.load()
        let today = todaysLog()

        // 오늘 남은 물어보는 시각들.
        let upcoming = reminders
            .filter(\.isEnabled)
            .compactMap { $0.triggerDate(on: now) }
            .filter { $0 > now }
            .sorted()

        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)

        var entries = ([now] + upcoming).map {
            entry(at: $0, colors: today.colors, pose: today.pose, reminders: reminders)
        }
        // 자정이 지나면 새 하루 — 빈 색으로 돌아간다.
        entries.append(entry(at: midnight, colors: Self.emptySlots, pose: nil, reminders: reminders))

        // 마지막 엔트리(자정)가 지나면 다음 날 타임라인을 새로 짠다.
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    // MARK: 보조

    private func entry(at date: Date, colors: [String], pose: BearPose?, reminders: [Reminder]) -> TodayColorEntry {
        TodayColorEntry(
            date: date,
            palette: currentPalette(),
            colors: colors,
            target: TodayColorView.target(
                slotColors: colors,
                due: Reminder.dueSlots(at: date, reminders: reminders)
            ),
            pose: pose
        )
    }

    private func currentPalette() -> ColorPalette {
        ColorPalette(
            storedValue: ColorLogStore.defaults.string(forKey: ColorLogStore.paletteKey)
                ?? ColorPalette.default.rawValue
        )
    }

    private static let emptySlots = Array(repeating: "", count: DailyColorLog.maxColorsPerDay)

    /// 오늘 하루치만 읽는다. 위젯 프로세스는 SwiftData 객체를 오래 들고 있지 않는다.
    private func todaysLog() -> (colors: [String], pose: BearPose?) {
        let context = ModelContext(ColorLogStore.shared)
        var descriptor = FetchDescriptor<DailyColorLog>(
            predicate: DailyColorLog.predicate(for: .now)
        )
        descriptor.fetchLimit = 1
        let log = try? context.fetch(descriptor).first
        return (log?.slotColors ?? Self.emptySlots, log?.pose)
    }
}

// MARK: - Widget

struct TodayColorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ColorLogToday", provider: TodayColorProvider()) { entry in
            TodayColorView(
                date: entry.date,
                colors: entry.colors,
                target: entry.target,
                palette: entry.palette,
                pose: entry.pose
            )
            // 색은 콘텐츠로 그린다. 컨테이너 배경은 시스템이 상황에 따라
            // 걷어 내므로(스탠바이·틴트 모드), 거기에 색을 두면 위젯이 통째로 비어 버린다.
            .containerBackground(for: .widget) { entry.palette.theme.background }
        }
        .configurationDisplayName("오늘의 색")
        .description("물어보는 시각마다 색 다섯이 나타나고, 고른 색으로 하루가 칠해집니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // 칠해진 얼굴은 가장자리까지 꽉 차야 '칸 하나'로 읽힌다.
        .contentMarginsDisabled()
    }
}
