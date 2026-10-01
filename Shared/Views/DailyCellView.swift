//
//  DailyCellView.swift
//  colorlog
//
//  하루 한 칸. 이 앱에서 사용자가 가장 오래 바라보게 될 단위.
//
//  네 가지 얼굴을 가진다.
//   · 기록됨(1~3색) → 수채화 블렌딩
//   · 오늘          → 진행 중. 기록이 있으면 수채화, 없으면 기다리는 얼굴
//   · 미래          → 글래스모피즘 빈칸
//   · 놓친 과거     → 존재하지만 가라앉은 빈칸
//

import SwiftUI

// MARK: - 오늘과의 관계

/// 그리드의 모든 칸은 '오늘'을 기준으로 자기 위치를 안다.
/// Step 3의 타임라인 매퍼가 이 값을 계산해 셀에 내려준다.
nonisolated enum DayRelation: Hashable, Sendable {
    case past
    case today
    case future

    init(date: Date, today: Date = .now, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        let reference = calendar.startOfDay(for: today)
        if day == reference {
            self = .today
        } else {
            self = day < reference ? .past : .future
        }
    }
}

// MARK: - 결정론적 난수

/// 날짜를 시드로 쓰는 SplitMix64.
/// 매 프레임 새 난수가 나오면 스크롤할 때마다 무늬가 요동친다.
/// 같은 날은 영원히 같은 번짐을 갖도록 시드를 날짜에 묶는다.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

nonisolated extension Date {
    /// 자정 기준 일련번호에서 뽑은 시드. 같은 날 = 같은 경계 각도.
    var colorSeed: UInt64 {
        let days = Int64(floor(timeIntervalSinceReferenceDate / 86_400))
        return UInt64(bitPattern: days &* 0x9E37_79B9)
    }
}

// MARK: - 플랫 컬러 필

/// 1~3개의 색을 한 칸에 채운다.
///
/// 이전에는 MeshGradient + 블러로 수채화처럼 번지게 했지만, 파스텔 + 큰 블러 조합이
/// 2010년대 그라데이션 배경처럼 읽혀 색이 탁해졌다. 색 자체가 감정을 지시해야 하는데
/// 번짐이 그 색을 흐려 버린 것.
///
/// 지금은 **하드 스톱 그라데이션**을 쓴다. 색은 단단하게 남고, 경계에서만
/// 한 줄 정도 짧게 섞인다. 경계의 각도는 날짜 시드에서 나와 날마다 다르다.
///
/// 입력은 자리 순서(아침·점심·저녁)이고 nil은 빈 자리다.
/// 빈 자리는 그리지 않고, 찬 색끼리만 순서대로 맞닿는다.
/// (사이에 낀 빈 자리를 옅은 띠로 남겨 봤는데, 어두운 팔레트에서는 거의 검은
/// 사선이 되어 색 위를 가로질렀다. 어느 자리가 비었는지는 원형 팔레트의
/// 자리 줄이 보여 준다.)
struct FlatColorFill: View {

    private let stops: [Gradient.Stop]
    private let angle: Angle
    private let solid: Color?

    /// 색이 갈라지는 경계의 폭. 전체 길이 대비 비율(경계 양쪽 각각).
    ///
    /// 처음엔 0.045였는데 46pt 칸에서 4pt 넘게 뭉개져 경계가 무너져 보였다.
    /// 완전히 0으로 두면 대각선이 계단처럼 깨지므로, 그라데이션이 스스로
    /// 안티에일리어싱할 만큼(한 픽셀 남짓)만 남긴다.
    private static let seam = 0.006

    init(pigments: [HexColor.Components?], seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let colors = pigments.compactMap { $0?.color }

        // 경계 각도. 45°를 기준으로 날마다 조금씩 흔들린다.
        // 완전 수직·수평이면 '줄무늬'로 보이므로 그 근처는 피한다.
        let base = Double.random(in: 30...60, using: &rng)
        let flipped = Bool.random(using: &rng)
        angle = .degrees(flipped ? base : -base + 180)

        switch colors.count {
        case 0:
            solid = nil
            stops = []
        case 1:
            solid = colors[0]
            stops = []
        case 2:
            solid = nil
            // 나누는 지점도 살짝 흔들어 둘로 정확히 접히지 않게 한다.
            let split = Double.random(in: 0.42...0.58, using: &rng)
            stops = [
                .init(color: colors[0], location: 0),
                .init(color: colors[0], location: split - Self.seam),
                .init(color: colors[1], location: split + Self.seam),
                .init(color: colors[1], location: 1),
            ]
        default:
            solid = nil
            let first = Double.random(in: 0.30...0.38, using: &rng)
            let second = Double.random(in: 0.62...0.70, using: &rng)
            stops = [
                .init(color: colors[0], location: 0),
                .init(color: colors[0], location: first - Self.seam),
                .init(color: colors[1], location: first + Self.seam),
                .init(color: colors[1], location: second - Self.seam),
                .init(color: colors[2], location: second + Self.seam),
                .init(color: colors[2], location: 1),
            ]
        }
    }

    var body: some View {
        if let solid {
            solid
        } else {
            LinearGradient(
                stops: stops,
                startPoint: .init(x: 0.5 - cos(angle.radians) / 2, y: 0.5 - sin(angle.radians) / 2),
                endPoint: .init(x: 0.5 + cos(angle.radians) / 2, y: 0.5 + sin(angle.radians) / 2)
            )
        }
    }
}

// MARK: - 셀

struct DailyCellView: View {

    let date: Date
    let colors: [String]
    let relation: DayRelation

    /// 오늘 칸처럼 시선을 붙잡아야 할 때.
    var isHighlighted: Bool = false
    /// 한 변 대비 모서리 반경 비율.
    var cornerRadiusRatio: Double = 0.22

    @Environment(\.paletteTheme) private var theme

    /// SwiftData 모델에서 바로 만드는 경로. (Step 3의 그리드가 쓴다)
    init(
        date: Date,
        log: DailyColorLog?,
        relation: DayRelation,
        isHighlighted: Bool = false,
        cornerRadiusRatio: Double = 0.22
    ) {
        self.date = date
        self.colors = log?.slotColors ?? []
        self.relation = relation
        self.isHighlighted = isHighlighted
        self.cornerRadiusRatio = cornerRadiusRatio
    }

    init(
        date: Date,
        colors: [String],
        relation: DayRelation,
        isHighlighted: Bool = false,
        cornerRadiusRatio: Double = 0.22
    ) {
        self.date = date
        self.colors = colors
        self.relation = relation
        self.isHighlighted = isHighlighted
        self.cornerRadiusRatio = cornerRadiusRatio
    }

    /// 자리 순서. nil은 빈 자리.
    private var pigments: [HexColor.Components?] {
        colors.prefix(DailyColorLog.maxColorsPerDay).map {
            $0.isEmpty ? nil : HexColor.components(from: $0)
        }
    }

    private var filledCount: Int { pigments.count { $0 != nil } }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let shape = RoundedRectangle(cornerRadius: side * cornerRadiusRatio, style: .continuous)

            face(side: side, canvas: proxy.size, shape: shape)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(shape)
                .overlay { border(side: side, shape: shape) }
                .shadow(
                    color: .black.opacity(isHighlighted ? 0.16 : 0),
                    radius: side * 0.10,
                    y: side * 0.03
                )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: 얼굴

    @ViewBuilder
    private func face(side: CGFloat, canvas: CGSize, shape: some Shape) -> some View {
        if filledCount == 0 {
            emptyFace(shape: shape)
        } else {
            filledFace(side: side)
        }
    }

    private func filledFace(side: CGFloat) -> some View {
        FlatColorFill(pigments: pigments, seed: date.colorSeed)
    }

    /// 지나간 빈 칸의 색.
    private var emptyTone: Color {
        theme.stroke.opacity(theme.colorScheme == .dark ? 0.58 : 0.74)
    }

    /// 빈 칸.
    ///
    /// 색이 플랫해지면서 유리 질감은 자리를 잃었다. 반투명 광택은 파스텔 시절의
    /// 어휘였고, 단단한 색 옆에서는 때가 낀 것처럼 보인다.
    /// 대신 **배경보다 한 톤 파인 자리**로 비어 있음을 말한다.
    /// 미래와 놓친 과거는 테두리의 유무로만 갈린다 — 기다리는 칸에는 선이 있고,
    /// 지나가 버린 칸에는 없다.
    @ViewBuilder
    private func emptyFace(shape: some Shape) -> some View {
        let isDark = theme.colorScheme == .dark
        switch relation {
        case .future:
            // 아직 오지 않은 날. 비어 있되 **또렷하게** 보여야 한다.
            // 너무 옅게 두면 격자 자체가 읽히지 않아 캔버스가 아니라 여백처럼 보인다.
            shape.fill(theme.stroke.opacity(isDark ? 0.34 : 0.42))
        case .past, .today:
            // 지나갔는데 비어 있는 날은 '채워진 회색'. 자리는 있었으나 아무것도 없었다.
            shape.fill(emptyTone)
        }
    }

    // MARK: 테두리

    @ViewBuilder
    private func border(side: CGFloat, shape: some InsettableShape) -> some View {
        if isHighlighted {
            shape.strokeBorder(theme.tint, lineWidth: max(2, side * 0.05))
        } else if filledCount == 0, relation == .future {
            // 아직 오지 않은 칸에만 선을 남긴다.
            // 채움이 옅은 만큼 이 선이 격자를 읽히게 하는 주역이라 또렷해야 한다.
            shape.strokeBorder(theme.inkSecondary.opacity(0.42), lineWidth: 1)
        }
    }

    // MARK: 접근성

    private var accessibilityDescription: String {
        let formatted = date.formatted(.dateTime.month(.wide).day().locale(.colorLog))
        return switch (relation, filledCount) {
        case (.future, _):  "\(formatted), 아직 오지 않은 날"
        case (_, 0):        "\(formatted), 기록 없음"
        case (.today, let count): "오늘 \(formatted), 색 \(count)개 기록됨"
        case (_, let count):      "\(formatted), 색 \(count)개 기록됨"
        }
    }
}

// MARK: - Preview

#Preview("셀 상태 모음") {
    @Previewable @State var palette: ColorPalette = .pantone

    let today = Calendar.current.startOfDay(for: .now)
    let day: (Int) -> Date = { Calendar.current.date(byAdding: .day, value: $0, to: today)! }

    return VStack(spacing: 28) {
        Picker("팔레트", selection: $palette) {
            ForEach(ColorPalette.allCases) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            DailyCellView(date: day(-1), colors: [palette.swatches[0].hex], relation: .past)
            DailyCellView(date: day(-2), colors: [palette.swatches[1].hex, palette.swatches[3].hex], relation: .past)
            DailyCellView(
                date: day(-3),
                colors: [palette.swatches[2].hex, palette.swatches[1].hex, palette.swatches[4].hex],
                relation: .past
            )
            DailyCellView(date: day(-4), colors: [], relation: .past)

            DailyCellView(date: today, colors: [palette.swatches[4].hex], relation: .today, isHighlighted: true)
            DailyCellView(date: today, colors: [], relation: .today, isHighlighted: true)
            DailyCellView(date: day(1), colors: [], relation: .future)
            DailyCellView(date: day(2), colors: [], relation: .future)
        }

        // 같은 색 조합이라도 날짜마다 경계 각도가 다르다는 것을 확인하는 줄.
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                DailyCellView(
                    date: day(-20 - index),
                    colors: [palette.swatches[0].hex, palette.swatches[3].hex, palette.swatches[2].hex],
                    relation: .past
                )
            }
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(palette.theme.backgroundGradient.ignoresSafeArea())
    .paletteTheme(palette)
    .preferredColorScheme(palette.theme.colorScheme)
    .animation(.smooth, value: palette)
}
