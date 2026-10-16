//
//  WatercolorBearView.swift
//  colorlog (앱 · 위젯 공용)
//
//  하루에 고른 색들이 곰돌이 실루엣 안에서 수채화처럼 번지는 뷰.
//
//  곰의 모양 · 연필 선 · 표정은 원화를 그대로 쓰고, 안쪽 물감만 사용자의 색으로 칠한다.
//  손으로 그린 곰을 도형으로 흉내 내면 비율이 조금만 틀어져도 귀여움이 무너진다.
//  그래서 `scripts/extract_bear_art.py`가 원화에서 세 겹을 뽑아 `BearArt.xcassets`에 넣는다.
//
//   · 실루엣(mask) — 외곽선 안쪽. 종이와 물감이 이 밖으로 번지지 않게 막는다.
//   · 원화 그대로(keep) — 사용자의 색으로 덮지 않는 자리. 흰 주둥이(벌린 입 속 혀 포함),
//     몸 안의 소품(책 · 도넛), 몸 밖의 색 있는 표시(하트 · 물방울 · 눈물).
//   · 연필(ink) — 갈색 외곽선 · 팔다리 선 · 표정 · 몸 밖 표시(z, 별, 음표, 움직임 선).
//
//  그 아래에 코드가 그리는 두 겹을 깐다.
//
//   · 종이 — 연한 미색 바탕에 아주 옅은 섬유 점. 물감이 multiply로 얹힐 바닥.
//   · 물감 — 가장자리가 울퉁불퉁한 얼룩들이 실루엣 안을 고르게 덮는다. 얼룩마다 묽은
//     바탕칠 · 진한 속칠 · 마르면서 고인 테두리를 겹친다. 블러는 가장자리만 살짝
//     누그러뜨린다. 블러로 경계를 다 녹이면 수채화가 아니라 에어브러시가 된다.
//     얼룩끼리는 multiply로 겹쳐 노랑 + 파랑이 겹친 자리는 초록이 된다.
//

import SwiftUI

struct WatercolorBearView: View {

    /// 감정 색상. 하루 기록은 1~3개지만 몇 개든 받는다.
    let moodColors: [Color]
    let pose: BearPose
    /// 칠할지, 선과 종이만 둘지, 옅은 선화로 둘지. 하루 칸이 어떤 얼굴인지는 `DayBear`가 정한다.
    let style: DayBear.Style
    /// 번짐 배치의 시드. 같은 시드 = 같은 번짐. 앱에서는 `date.colorSeed`를 넘긴다.
    let seed: UInt64
    /// 처음 나타날 때 번질지. 격자 칸은 이미 칠해진 채로 나타나고, 색이 바뀔 때만 번진다.
    /// 스크롤로 칸이 다시 나타날 때마다 번지면 캔버스가 쉴 새 없이 꿈틀댄다.
    let bloomsOnAppear: Bool

    /// 0이면 물감이 아직 종이에 닿기 전, 1이면 다 번진 상태.
    @State private var bloom: CGFloat
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// 하루 칸의 곰 그대로. 오늘 칸 · 지난 칸 · 미래 칸이 모두 이 길로 그린다.
    init(day: DayBear, colors: [Color], seed: UInt64, bloomsOnAppear: Bool = true) {
        self.init(moodColors: colors, pose: day.pose, style: day.style, seed: seed, bloomsOnAppear: bloomsOnAppear)
    }

    init(
        moodColors: [Color],
        pose: BearPose = .standing,
        style: DayBear.Style = .painted,
        seed: UInt64 = 0,
        bloomsOnAppear: Bool = true
    ) {
        self.moodColors = moodColors
        self.pose = pose
        self.style = style
        self.seed = seed
        self.bloomsOnAppear = bloomsOnAppear
        // 번지지 않고 나타나는 곰은 첫 프레임부터 다 칠해져 있어야 한 번 깜빡이지 않는다.
        _bloom = State(initialValue: bloomsOnAppear ? 0 : 1)
    }

    /// 실제로 칠할 색. 칠하는 얼굴이 아니면 색을 받아도 쓰지 않는다.
    private var paints: [Color] { style == .painted ? moodColors : [] }

    var body: some View {
        Group {
            if style == .lineArt {
                lineArt
            } else {
                watercolor
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    /// 아직 오지 않았거나 아무것도 남기지 않은 날. 연필 선만 옅은 회색으로.
    /// 종이도 물감도 깔지 않아 배경이 그대로 비친다.
    private var lineArt: some View {
        // 갈색 연필 선을 회색으로 빼서 옅게 둔다. 어두운 배경에서는 회색 선이 바탕에 묻히므로
        // 밝기를 뒤집어 옅은 회색 선으로 그린다.
        pose.art(.ink)
            .grayscale(1)
            .colorInvert(colorScheme == .dark)
            .opacity(colorScheme == .dark ? 0.32 : 0.28)
    }

    /// 동작 이름은 읽어 주지 않는다. 날짜로 뽑은 동작이라, 화난 곰이 나와도
    /// 그날 기분을 앱이 판단한 게 아니다.
    private var accessibilityText: String {
        switch style {
        case .painted: "색 \(paints.count)개로 칠한 곰"
        case .bare: "아직 칠하지 않은 곰"
        case .lineArt: "빈 날"
        }
    }

    private var watercolor: some View {
        // 배치는 여기서 한 번만 계산한다. 물감 층은 애니메이션 프레임마다 다시 그려진다.
        let washes = WatercolorWash.layout(count: paints.count, seed: seed, occupancy: pose.occupancy)

        return ZStack {
            // 종이와 물감은 하나로 묶어 마스크한다.
            // compositingGroup이 없으면 multiply가 곰돌이 밖의 화면 배경과도 섞인다.
            ZStack {
                WatercolorPaper(seed: seed)
                WatercolorPaint(colors: paints, washes: washes, bloom: bloom)
                    .blendMode(.multiply)
            }
            .compositingGroup()
            .mask(pose.art(.mask))

            pose.art(.keep)
            pose.art(.ink)
        }
        // 색 · 자세 · 시드 중 하나라도 바뀌면 다시 번진다.
        .task(id: BloomKey(colors: paints, pose: pose, seed: seed)) {
            let isFirst = !hasAppeared
            hasAppeared = true
            guard !reduceMotion, bloomsOnAppear || !isFirst else {
                bloom = 1
                return
            }
            bloom = 0
            // 0으로 되돌린 것이 한 프레임 그려진 뒤에 번지기 시작해야 애니메이션이 보인다.
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.easeInOut(duration: 2.0)) { bloom = 1 }
        }
    }
}

/// 다시 번질지 정하는 키.
private struct BloomKey: Equatable {
    let colors: [Color]
    let pose: BearPose
    let seed: UInt64
}

// MARK: - 자세

enum BearPose: String, CaseIterable, Identifiable {
    /// 정면으로 선 기본 자세.
    case standing
    case waving
    case sleeping
    case sitting
    case jumping
    case cheering
    case running
    /// 도넛을 두 손으로 들고 먹는다.
    case eating
    /// 엎드려 책을 읽는다.
    case reading
    /// 허리에 손을 얹고 뿌듯하게 웃는다.
    case proud
    case pointing
    /// 바닥에 엎드려 눈만 빼꼼 내민다.
    case peeking
    case angry
    case crying

    var id: Self { self }

    enum Layer: String {
        case ink = "Ink"
        case mask = "Mask"
        case keep = "Keep"
    }

    /// 원화에서 뽑은 한 겹. 모든 겹은 같은 정사각형이라 그대로 포개면 맞는다.
    func art(_ layer: Layer) -> some View {
        Image("Bear\(layer.rawValue)\(rawValue.capitalized)")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .allowsHitTesting(false)
    }

    /// 실루엣이 차지하는 20×20 칸. `#`이 몸. `scripts/extract_bear_art.py`의 출력.
    /// 물감 얼룩은 이 칸 안에만 놓는다.
    fileprivate var occupancy: [String] {
        switch self {
        case .standing: [
            "....................",
            ".....##.########....",
            "....############....",
            "....############....",
            "....############....",
            "...##############...",
            "...##############...",
            "...##############...",
            "...##############...",
            "..################..",
            "..################..",
            ".##################.",
            ".##################.",
            ".##################.",
            "..################..",
            "..################..",
            "..################..",
            "...##############...",
            "....####.....###....",
            "....................",
        ]
        case .waving: [
            "....................",
            ".....##.######......",
            ".....##########.....",
            ".....##########.....",
            ".....##########.....",
            "....#############...",
            "....##############..",
            "....##############..",
            "....#############...",
            "...##############...",
            "...#############....",
            "..##############....",
            "..##############....",
            "...#############....",
            "....############....",
            "....###########.....",
            ".....##########.....",
            ".....##########.....",
            "......##....##......",
            "....................",
        ]
        case .sleeping: [
            "....................",
            "....................",
            "....................",
            "....................",
            "........#...........",
            ".......###..........",
            ".....##########.....",
            "....#############...",
            "...################.",
            "..#################.",
            ".##################.",
            ".##################.",
            "..#################.",
            "..#################.",
            "...################.",
            "...################.",
            "...###############..",
            "....######..........",
            "....................",
            "....................",
        ]
        case .sitting: [
            "....................",
            ".......######.......",
            ".....##########.....",
            "...############.....",
            "...#############....",
            "....############....",
            "....#############...",
            "....#############...",
            "....#############...",
            "....#############...",
            "....##############..",
            "...###############..",
            "...###############..",
            "...###############..",
            "..################..",
            ".##################.",
            ".#################..",
            "..##############....",
            ".........####.......",
            "....................",
        ]
        case .jumping: [
            "....................",
            "....................",
            "........#####.......",
            ".....########.......",
            "....##########......",
            "....##########.#....",
            "....#############...",
            "....#############...",
            "..##############....",
            "..##############....",
            "...#############....",
            "....############....",
            ".....###########....",
            ".....###########....",
            ".....###########....",
            ".....###########....",
            "......##########....",
            ".......###..........",
            "........##..........",
            "....................",
        ]
        case .cheering: [
            "....................",
            "....................",
            "....................",
            "......########......",
            ".....#########......",
            ".....#########......",
            "....############....",
            "...##############...",
            "...##############...",
            "...#############....",
            "....############....",
            "....###########.....",
            "....###########.....",
            "....###########.....",
            "....###########.....",
            "....###########.....",
            ".....##########.....",
            ".....#########......",
            "......##...###......",
            "....................",
        ]
        case .running: [
            "....................",
            "....................",
            "..........##........",
            "....#########.......",
            "....#########.......",
            "....#########.......",
            "....##########......",
            "....############....",
            "....#############...",
            "..###############...",
            "..##############....",
            "..##############....",
            "....############....",
            ".....###########....",
            ".....############...",
            ".....############...",
            ".....####...........",
            ".....###............",
            "....................",
            "....................",
        ]
        case .eating: [
            "....................",
            ".....##.####.##.....",
            ".....###########....",
            ".....###########....",
            ".....###########....",
            "....############....",
            "....############....",
            "....############....",
            "....############....",
            "...##############...",
            "...##############...",
            "...##############...",
            "....##############..",
            "....##############..",
            "..################..",
            ".#################..",
            "..################..",
            "..##############....",
            ".........#####......",
            "....................",
        ]
        case .reading: [
            "....................",
            "....................",
            "....................",
            "....................",
            "....................",
            "....................",
            "...#############....",
            "..###############...",
            "...##############...",
            "...##############...",
            "..################..",
            ".##################.",
            ".##################.",
            ".################...",
            "..#########.........",
            "...#####............",
            "....................",
            "....................",
            "....................",
            "....................",
        ]
        case .proud: [
            "....................",
            ".....#######.##.....",
            ".....###########....",
            ".....###########....",
            "....############....",
            "....############....",
            "...#############....",
            "...#############....",
            "...#############....",
            "...##############...",
            "..################..",
            "..################..",
            "..################..",
            "...##############...",
            "....#############...",
            "....#############...",
            "....#############...",
            "....############....",
            "....###.....####....",
            "....................",
        ]
        case .pointing: [
            "....................",
            "...........##.......",
            "....##########......",
            "....##########......",
            "....##########......",
            "....###########.....",
            "....############....",
            "....############....",
            "....###############.",
            "..#################.",
            "..################..",
            ".#################..",
            ".##############.....",
            "..#############.....",
            "..#############.....",
            "..#############.....",
            "....##########......",
            "....##########......",
            "....####...###......",
            "....................",
        ]
        case .peeking: [
            "....................",
            "....................",
            "....................",
            ".............###....",
            "........#########...",
            "......###########...",
            "..###############...",
            ".################...",
            ".#################..",
            ".#################..",
            "..################..",
            "...###############..",
            "...###############..",
            "...################.",
            "...################.",
            "...################.",
            "...#####......####..",
            "....................",
            "....................",
            "....................",
        ]
        case .angry: [
            "....................",
            "....................",
            "....................",
            ".....#########......",
            ".....#########......",
            ".....##########.....",
            ".....##########.....",
            "....############....",
            "....############....",
            "....############....",
            "...##############...",
            "...##############...",
            "...##############...",
            "...#############....",
            "....############....",
            "....############....",
            ".....##########.....",
            ".....##########.....",
            ".....###....###.....",
            "....................",
        ]
        case .crying: [
            "....................",
            ".....##.#######.....",
            "....############....",
            "....###########.....",
            ".....##########.....",
            "....############....",
            "....############....",
            "....############....",
            "...#############....",
            "...#############....",
            "....############....",
            "....############....",
            "....#############...",
            "....#############...",
            "....##############..",
            "..################..",
            "..################..",
            "...############.....",
            "........#####.......",
            "....................",
        ]
        }
    }
}

// MARK: - 물감

/// 물감 층. `bloom`을 Animatable로 받아 애니메이션 프레임마다 얼룩 크기를 다시 그린다.
/// 원화 겹과 종이는 이 뷰 밖에 있어 번지는 동안 다시 그려지지 않는다.
private struct WatercolorPaint: View, Animatable {
    let colors: [Color]
    let washes: [WatercolorWash]
    var bloom: CGFloat

    var animatableData: CGFloat {
        get { bloom }
        set { bloom = newValue }
    }

    var body: some View {
        Canvas { context, size in
            context.blendMode = .multiply
            let w = size.width

            for wash in washes {
                let t = wash.progress(at: bloom)
                guard t > 0 else { continue }

                let radius = wash.radius * w * (0.45 + 0.55 * t)
                let center = CGPoint(x: wash.center.x * w, y: wash.center.y * size.height)
                let pigment = colors[wash.colorIndex]
                let outline = wash.path(center: center, radius: radius)

                let inner = wash.path(
                    center: CGPoint(x: center.x + wash.innerOffset.x * radius,
                                    y: center.y + wash.innerOffset.y * radius),
                    radius: radius * 0.6)

                // 가장자리만 누그러뜨린다. 반지름의 6% — 경계는 보이되 칼로 자른 듯하지는 않게.
                // 격자 칸처럼 작을 땐 이 블러가 반 픽셀도 안 돼 눈에 보이지 않는다.
                // 그 크기에서는 레이어(오프스크린 버퍼)를 열지 않고 바로 칠한다 — 칸 하나를
                // 그리는 비용 대부분이 얼룩마다 여는 레이어였다.
                guard radius * 0.06 >= 0.75 else {
                    // 테두리도 뺀다. 블러 없이 작게 그리면 테두리끼리 이어져 잎맥 같은 금으로 보인다.
                    context.fill(outline, with: .color(pigment.opacity(0.19 * t)))
                    context.fill(inner, with: .color(pigment.opacity(0.1 * t)))
                    continue
                }

                context.drawLayer { layer in
                    layer.blendMode = .multiply
                    layer.opacity = t
                    layer.addFilter(.blur(radius: radius * 0.06))

                    // 묽은 바탕칠.
                    layer.fill(outline, with: .color(pigment.opacity(0.19)))
                    // 물감이 더 고인 속칠. 가운데에서 비켜 앉아 얼룩 안에 농담이 생긴다.
                    layer.fill(inner, with: .color(pigment.opacity(0.1)))
                    // 마르면서 가장자리로 밀려 고인 안료. 수채화가 수채화로 읽히는 건 이 테두리 덕이다.
                    layer.stroke(outline, with: .color(pigment.opacity(0.18)),
                                 lineWidth: max(radius * 0.045, 1))
                }
            }
        }
    }
}

// MARK: - 얼룩 배치

/// 물감 얼룩 하나. 좌표와 반지름은 단위 정사각형 기준.
private struct WatercolorWash {
    let colorIndex: Int
    let center: CGPoint
    let radius: CGFloat
    /// 속칠이 가운데에서 비켜 앉는 정도. 반지름에 대한 비율.
    let innerOffset: CGPoint
    /// 이 얼룩이 번지기 시작하는 bloom 값.
    let delay: CGFloat
    /// 둘레 각 지점의 반지름 배율. 얼룩마다 다른 울퉁불퉁함.
    let contour: [CGFloat]

    /// 번짐 진행도 0~1. 늦게 시작한 얼룩도 bloom이 1이 될 때 함께 다 번진다.
    func progress(at bloom: CGFloat) -> CGFloat {
        min(max((bloom - delay) / (1 - delay), 0), 1)
    }

    /// 울퉁불퉁한 둘레를 이웃 점의 중점을 잇는 곡선으로 매끈하게 닫는다.
    func path(center: CGPoint, radius: CGFloat) -> Path {
        let points = contour.enumerated().map { index, scale in
            let angle = Double(index) / Double(contour.count) * 2 * .pi
            return CGPoint(x: center.x + cos(angle) * radius * scale,
                           y: center.y + sin(angle) * radius * scale)
        }
        return Path.smoothClosed(through: points)
    }

    /// 실루엣 안을 고르게 덮도록 얼룩 자리를 고르고, 색은 가까운 색 구역을 따른다.
    ///
    /// 자리는 점유 격자의 몸 칸마다 후보를 하나씩 두고, 서로 일정 거리 이상 떨어진 것만 고른다.
    /// 칸이 촘촘해서 귀나 팔 끝처럼 작은 부위도 빈 종이로 남지 않는다.
    ///
    /// 원화는 색이 구역별로 모여 있으면서도 군데군데 다른 색 얼룩이 섞여 있다.
    /// 그래서 대부분은 가까운 구역의 색을, 다섯에 하나 꼴로 다른 색을 칠한다.
    static func layout(count: Int, seed: UInt64, occupancy: [String]) -> [WatercolorWash] {
        guard count > 0 else { return [] }
        var rng = SeededGenerator(seed: seed ^ 0xB3A2_5EED)

        let cell = 1 / CGFloat(occupancy.count)
        var candidates: [CGPoint] = []
        for (row, line) in occupancy.enumerated() {
            for (column, mark) in line.enumerated() where mark == "#" {
                candidates.append(CGPoint(
                    x: (CGFloat(column) + .random(in: 0.2...0.8, using: &rng)) * cell,
                    y: (CGFloat(row) + .random(in: 0.2...0.8, using: &rng)) * cell))
            }
        }
        guard !candidates.isEmpty else { return [] }

        let box = candidates.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        candidates.shuffle(using: &rng)
        var spots: [CGPoint] = []
        for point in candidates where spots.allSatisfy({ $0.distance(to: point) >= 0.15 }) {
            spots.append(point)
        }

        // 색 구역 중심. 몸의 바운딩 박스를 기준으로 나누고, 어느 색이 어디 앉을지는 시드가 정한다.
        let mid = CGPoint(x: box.midX, y: box.midY)
        func zone(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: mid.x + dx * box.width, y: mid.y + dy * box.height)
        }
        var zones: [CGPoint] = switch count {
        case 1: [mid]
        case 2: [zone(-0.22, -0.2), zone(0.22, 0.2)]
        case 3: [zone(-0.24, -0.22), zone(0.24, -0.2), zone(0, 0.28)]
        default: (0..<count).map { index in
            let angle = -3 * Double.pi / 4 + Double(index) * 2 * .pi / Double(count)
            return zone(cos(angle) * 0.3, sin(angle) * 0.3)
        }
        }
        zones.shuffle(using: &rng)

        return spots.map { spot in
            let nearest = zones.indices.min { zones[$0].distance(to: spot) < zones[$1].distance(to: spot) }!
            let colorIndex = count > 1 && Double.random(in: 0...1, using: &rng) < 0.2
                ? Int.random(in: 0..<count, using: &rng)
                : nearest

            // 낮은 주파수 둘에 높은 주파수 하나를 섞어야 동그라미도 별 모양도 아닌 얼룩이 된다.
            let phases = (0..<3).map { _ in Double.random(in: 0..<(2 * .pi), using: &rng) }
            let contour = (0..<40).map { index -> CGFloat in
                let angle = Double(index) / 40 * 2 * .pi
                return CGFloat(1
                    + 0.14 * sin(2 * angle + phases[0])
                    + 0.07 * sin(5 * angle + phases[1])
                    + 0.035 * sin(11 * angle + phases[2]))
            }

            return WatercolorWash(
                colorIndex: colorIndex,
                center: spot,
                radius: .random(in: 0.12...0.16, using: &rng),
                innerOffset: CGPoint(x: .random(in: -0.3...0.3, using: &rng),
                                     y: .random(in: -0.3...0.3, using: &rng)),
                // 하루에 고른 순서대로 한 색씩 늦게 번진다.
                delay: CGFloat(colorIndex) / CGFloat(count) * 0.45 + .random(in: 0...0.12, using: &rng),
                contour: contour)
        }
    }
}

private extension View {
    @ViewBuilder
    func colorInvert(_ isOn: Bool) -> some View {
        if isOn { colorInvert() } else { self }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private extension Path {
    /// 점들의 중점을 지나고 각 점을 조절점으로 쓰는 닫힌 곡선.
    static func smoothClosed(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }

        path.move(to: mid(last, first))
        for index in points.indices {
            let point = points[index]
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: mid(point, next), control: point)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 종이

/// 연한 미색 종이. 섬유 점은 시드로 고정해 다시 그려도 질감이 요동치지 않는다.
private struct WatercolorPaper: View {
    let seed: UInt64

    static let base = Color(red: 0.995, green: 0.984, blue: 0.962)

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.base))

            var rng = SeededGenerator(seed: seed ^ 0x9A9E_5000)
            let grains = Int(size.width * size.height / 70)
            for _ in 0..<grains {
                let point = CGPoint(x: .random(in: 0..<size.width, using: &rng),
                                    y: .random(in: 0..<size.height, using: &rng))
                let radius = CGFloat.random(in: 0.4...1.2, using: &rng)
                let tone = Double.random(in: 0...1, using: &rng) < 0.5
                    ? Color(red: 0.55, green: 0.48, blue: 0.4).opacity(0.08)
                    : Color.white.opacity(0.6)
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: radius, height: radius)),
                             with: .color(tone))
            }
        }
    }
}

// MARK: - 자세 모음

/// 자세들을 한 줄로 세우고 아래에 손글씨 이름을 단 시트. 미리보기와 디자인 확인용.
struct BearPoseSheet: View {
    var poses: [BearPose] = Self.poses
    /// 수채 물감 같은 중간 채도의 다섯 색. 시스템 기본색은 multiply로 겹치면 탁해진다.
    var colors: [Color] = [
        Color(red: 0.4, green: 0.64, blue: 0.92),   // 파랑
        Color(red: 0.95, green: 0.52, blue: 0.6),   // 분홍
        Color(red: 0.98, green: 0.84, blue: 0.38),  // 노랑
        Color(red: 0.68, green: 0.55, blue: 0.88),  // 보라
        Color(red: 0.98, green: 0.68, blue: 0.48),  // 주황
    ]
    var seed: UInt64 = 0

    static let poses: [BearPose] = [.waving, .sleeping, .sitting, .jumping, .cheering]
    static let moods: [BearPose] = [.running, .eating, .reading, .proud, .pointing, .peeking, .angry, .crying]
    /// 원화 연필 선과 같은 짙은 갈색.
    static let ink = Color(red: 0.33, green: 0.22, blue: 0.17)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(poses) { pose in
                VStack(spacing: 6) {
                    WatercolorBearView(moodColors: colors, pose: pose, seed: seed)
                    Text(pose.rawValue)
                        .font(.custom("ChalkboardSE-Regular", size: 15, relativeTo: .caption))
                        .foregroundStyle(Self.ink)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .background(Color.white)
    }
}

// MARK: - 미리보기

#Preview("자세 다섯", traits: .landscapeLeft) {
    BearPoseSheet()
        .frame(maxHeight: .infinity)
        .background(Color.white)
}

#Preview("동작 여덟", traits: .landscapeLeft) {
    BearPoseSheet(poses: BearPoseSheet.moods)
        .frame(maxHeight: .infinity)
        .background(Color.white)
}

#Preview("날마다 곰") {
    // 지난 열흘 · 오늘 · 다가올 사흘. 채운 자리 수를 날마다 바꿔 세 얼굴을 모두 본다.
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let palette = ColorPalette.default.swatches.map(\.color)
    let days = (-10...3).map { calendar.date(byAdding: .day, value: $0, to: today)! }

    LazyVGrid(columns: Array(repeating: GridItem(spacing: 6), count: 7), spacing: 6) {
        ForEach(days, id: \.self) { day in
            let offset = calendar.dateComponents([.day], from: today, to: day).day!
            let filled = offset == 0 ? 0 : [0, 1, 2, 3, 3, 1, 2][(offset + 70) % 7]
            WatercolorBearView(
                day: DayBear(date: day, filledCount: filled, relation: DayRelation(date: day, today: today)),
                colors: (0..<filled).map { palette[(offset + 70 + $0 * 2) % palette.count] },
                seed: day.colorSeed)
        }
    }
    .padding()
}

#Preview("빨강 · 노랑 · 파랑") {
    WatercolorBearView(moodColors: [.red, .yellow, .blue], seed: 1)
        .padding(40)
}

#Preview("분홍 · 보라") {
    WatercolorBearView(moodColors: [.pink, .purple], pose: .waving, seed: 2)
        .padding(40)
}

#Preview("색 하나") {
    WatercolorBearView(moodColors: [Color(red: 0.55, green: 0.75, blue: 0.95)], pose: .sitting, seed: 3)
        .padding(40)
}

#Preview("다시 번지기") {
    @Previewable @State var seed: UInt64 = 7
    @Previewable @State var pose: BearPose = .cheering
    VStack(spacing: 32) {
        WatercolorBearView(moodColors: [.orange, .teal, .indigo], pose: pose, seed: seed)
        Picker("자세", selection: $pose) {
            ForEach(BearPose.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        Button("다시 칠하기", systemImage: "paintbrush") { seed &+= 1 }
            .buttonStyle(.borderedProminent)
    }
    .padding(40)
}
