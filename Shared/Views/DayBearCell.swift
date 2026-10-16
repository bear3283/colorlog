//
//  DayBearCell.swift
//  colorlog (앱 · 위젯 공용)
//
//  격자의 하루 한 칸. 칸마다 곰 한 마리가 앉는다.
//
//  어떤 곰이 어떤 얼굴로 앉을지는 `DayBear`가 정한다.
//   · 칠한 날     → 그날의 색으로 칠한 곰. 동작은 날짜로 고정한 무작위.
//   · 빈 오늘     → 색 없이 시무룩하게 앉아 첫 색을 기다리는 곰.
//   · 미래 · 빈 지난날 → 옅은 회색 선화. 자리는 있되 아직(또는 끝내) 비어 있다.
//
//  칸에는 테두리도 그림자도 없다. 오늘만 곰 뒤에 아주 옅은 빛이 고인다.
//

import SwiftUI

struct DayBearCell: View {

    let date: Date
    /// 자리 순서의 HEX. ""는 빈 자리.
    let colors: [String]
    let relation: DayRelation
    var isHighlighted: Bool = false

    @Environment(\.paletteTheme) private var theme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(date: Date, log: DailyColorLog?, relation: DayRelation, isHighlighted: Bool = false) {
        self.init(date: date, colors: log?.slotColors ?? [], relation: relation, isHighlighted: isHighlighted)
    }

    init(date: Date, colors: [String], relation: DayRelation, isHighlighted: Bool = false) {
        self.date = date
        self.colors = colors
        self.relation = relation
        self.isHighlighted = isHighlighted
    }

    private var filled: [String] { colors.prefix(DailyColorLog.maxColorsPerDay).filter { !$0.isEmpty } }

    private var day: DayBear { DayBear(date: date, filledCount: filled.count, relation: relation) }

    var body: some View {
        ZStack {
            if relation == .today {
                todayBear
            } else if relation == .past, day.style == .painted {
                // 지나간 칠한 날은 다시 바뀔 일이 드물다. 한 번 그린 그림을 그대로 쓴다.
                GeometryReader { proxy in
                    if let image = cachedImage(side: proxy.size.width) {
                        Image(uiImage: image).resizable()
                    } else {
                        bear
                    }
                }
            } else {
                bear
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityDescription)
    }

    /// 오늘. 테두리 없이 세 가지로 눈에 띈다.
    ///  · 곰 뒤에 팔레트 틴트가 둥글게 고인다.
    ///  · 곰이 이웃보다 한 치수 크다. 발을 기준으로 키워 행의 바닥선은 그대로다.
    ///  · 곰이 천천히 숨을 쉰다. 격자에서 움직이는 건 오늘뿐이라 눈이 먼저 간다.
    ///    아직 칠하지 않은 오늘엔 '기다리고 있다'는 뜻도 된다.
    private var todayBear: some View {
        ZStack {
            if isHighlighted {
                Circle()
                    .fill(theme.tint.opacity(theme.colorScheme == .dark ? 0.42 : 0.3))
                    .scaleEffect(1.05)
                    .blur(radius: 7)
            }

            if reduceMotion {
                bear
            } else {
                bear.phaseAnimator([false, true]) { content, isInhaling in
                    content.scaleEffect(x: isInhaling ? 1.015 : 1, y: isInhaling ? 1.04 : 1, anchor: .bottom)
                } animation: { _ in
                    .easeInOut(duration: 2.2)
                }
            }
        }
        .scaleEffect(isHighlighted ? 1.18 : 1, anchor: .bottom)
    }

    private var bear: some View {
        WatercolorBearView(
            day: day,
            colors: filled.map { Color(hex: $0, fallback: .gray) },
            seed: date.colorSeed,
            bloomsOnAppear: false)
    }

    private func cachedImage(side: CGFloat) -> UIImage? {
        guard side > 0 else { return nil }
        let key = "\(date.timeIntervalSinceReferenceDate)|\(filled.joined(separator: ","))|\(Int(side * displayScale))"
        return BearCellCache.image(for: key) {
            let renderer = ImageRenderer(content: bear.frame(width: side, height: side))
            renderer.scale = displayScale
            return renderer.uiImage
        }
    }

    private var accessibilityDescription: String {
        let formatted = date.formatted(.dateTime.month(.wide).day().locale(.colorLog))
        return switch (relation, filled.count) {
        case (.future, _): "\(formatted), 아직 오지 않은 날"
        case (_, 0): "\(formatted), 기록 없음"
        case (.today, let count): "오늘 \(formatted), 색 \(count)개 기록됨"
        case (_, let count): "\(formatted), 색 \(count)개 기록됨"
        }
    }
}

/// 지나간 칠한 칸의 그림 캐시.
///
/// 칠한 곰 한 칸은 종이 · 물감 · 마스크 · 원화 세 겹을 합성하느라 선화 칸보다 열 배 넘게 든다.
/// 격자는 스크롤할 때마다 행을 다시 만들므로, 같은 칸을 매번 새로 합성하면 스크롤이 버벅인다.
/// 날짜 · 색 · 픽셀 크기가 같으면 그림도 같으니 한 번 그린 걸 재사용한다.
/// 한 칸이 약 70KB(135px 정사각형)라 최근 240칸(약 17MB)만 들고 있는다.
@MainActor
enum BearCellCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 240
        return cache
    }()

    static func image(for key: String, render: () -> UIImage?) -> UIImage? {
        if let hit = images.object(forKey: key as NSString) { return hit }
        guard let made = render() else { return nil }
        images.setObject(made, forKey: key as NSString)
        return made
    }
}
