//
//  MonthPosterView.swift
//  colorlog
//
//  월간 곰 포스터 — 한 달의 곰을 달력 모양으로 한 장에 모은 그림. 이미지로 렌더해 공유한다.
//
//  앱 캔버스는 글자가 없지만, 포스터는 앱 밖(메시지 · SNS)으로 나가는 그림이라
//  '언제의 기록인지'를 손글씨 제목과 날짜 숫자로 적는다. 점수 · 연속 일수 같은 비교는 넣지 않고,
//  아래 띠에 그 달에 고른 색의 비율만 수채 띠로 보인다.
//  바탕은 팔레트와 상관없이 흰 종이 — 어디에 붙여도 곰과 색이 가장 또렷하다.
//

import SwiftUI

struct MonthPosterView: View {
    let poster: MonthPoster
    var today: Date = .now
    var calendar: Calendar = .current

    /// 포스터의 크기(포인트). 3배로 렌더하면 1080×1440 — SNS 세로 비율(3:4).
    static let size = CGSize(width: 360, height: 480)

    private static let paper = Color(red: 0.995, green: 0.984, blue: 0.962)
    private static let ink = Color(red: 0.29, green: 0.22, blue: 0.18)

    private var localizedCalendar: Calendar {
        var calendar = calendar
        calendar.locale = .colorLog
        return calendar
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 22)
            weekdays
                .padding(.top, 12)
            grid
                .padding(.top, 4)
            Spacer(minLength: 8)
            colorStrip
            footer
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 18)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Self.paper)
        .foregroundStyle(Self.ink)
        .environment(\.colorScheme, .light)
    }

    // MARK: 제목

    private var header: some View {
        VStack(spacing: 0) {
            Text(poster.monthStart.formatted(.dateTime.month(.wide).locale(.colorLog)))
                .font(.gaegu(size: 38, relativeTo: .largeTitle))
            Text(poster.monthStart.formatted(.dateTime.year().locale(.colorLog)))
                .font(.gaegu(size: 16, relativeTo: .caption))
                .opacity(0.6)
        }
    }

    // MARK: 달력

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    }

    private var weekdays: some View {
        let symbols = localizedCalendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = (0..<7).map { symbols[(first + $0) % 7] }
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.gaegu(size: 13, relativeTo: .caption2))
                    .opacity(0.5)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(Array(poster.cells.enumerated()), id: \.offset) { _, cell in
                if let cell {
                    dayCell(cell)
                } else {
                    Color.clear.frame(height: 1)
                }
            }
        }
    }

    private func dayCell(_ day: MonthPoster.Day) -> some View {
        let date = day.key.startOfDay(in: calendar)
        let filled = day.filledColors
        let relation = DayRelation(date: date, today: today, calendar: calendar)
        let bear = DayBear(
            date: date, filledCount: filled.count, relation: relation,
            storedPose: day.poseRawValue.flatMap(BearPose.init(rawValue:)))
        return VStack(spacing: -3) {
            WatercolorBearView(
                day: bear,
                colors: filled.map { Color(hex: $0, fallback: .gray) },
                seed: date.colorSeed,
                bloomsOnAppear: false)
            Text(verbatim: "\(day.key.day)")
                .font(.gaegu(size: 10, relativeTo: .caption2))
                .opacity(filled.isEmpty ? 0.35 : 0.7)
        }
    }

    // MARK: 색 띠

    /// 그 달에 고른 색의 비율. 숫자 대신 폭으로만.
    private var colorStrip: some View {
        let total = max(poster.colorCounts.reduce(0) { $0 + $1.count }, 1)
        return GeometryReader { proxy in
            HStack(spacing: 2) {
                if poster.colorCounts.isEmpty {
                    Capsule().stroke(Self.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                } else {
                    ForEach(Array(poster.colorCounts.enumerated()), id: \.offset) { _, entry in
                        Capsule()
                            .fill(Color(hex: entry.hex, fallback: .gray).opacity(0.85))
                            .frame(width: max(proxy.size.width * CGFloat(entry.count) / CGFloat(total) - 2, 3))
                    }
                }
            }
        }
        .frame(height: 12)
    }

    private var footer: some View {
        HStack {
            Text("칠한 날 \(poster.recordedDays)일", comment: "월간 곰 포스터. 색을 하나라도 고른 날 수")
                .font(.gaegu(size: 14, relativeTo: .caption))
                .opacity(0.7)
            Spacer()
            Text("칼라베어")
                .font(.gaegu(size: 14, relativeTo: .caption))
                .opacity(0.5)
        }
    }
}

extension MonthPosterView {
    /// 공유할 이미지(3배, 1080×1440).
    @MainActor
    func rendered(scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

#if DEBUG
#Preview("월간 곰 포스터") {
    let palette = Palette(preset: .pantone)
    let hexes = palette.swatches.map(\.hex)
    let calendar = Calendar.current
    let start = calendar.dateInterval(of: .month, for: .now)!.start
    var records: [DayKey: (colors: [String], pose: String?)] = [:]
    for offset in 0..<20 where offset % 4 != 3 {
        let date = calendar.date(byAdding: .day, value: offset, to: start)!
        records[DayKey(date)] = ((0..<3).map { hexes[(offset + $0 * 2) % hexes.count] }, nil)
    }
    return MonthPosterView(poster: MonthPoster(month: start, records: records))
}
#endif
