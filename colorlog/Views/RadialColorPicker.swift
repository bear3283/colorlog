//
//  RadialColorPicker.swift
//  colorlog
//
//  칸을 누르면 그 칸에서 색이 튀어나와 원으로 둘러선다.
//
//  이전에는 행이 아래로 밀리면서 스와치 줄이 나타났는데, 격자가 통째로 움직이니
//  '내가 누른 칸'과 '고르는 색' 사이의 연결이 끊겼다. 지금은 격자가 멈춰 있고
//  색만 그 자리에서 퍼져 나온다.
//
//  두 층으로 되어 있다.
//   · 자리 줄 — 원 바깥(위, 자리가 없으면 아래)에 아침·점심·저녁 세 자리가
//     왼쪽부터 놓인다. 찬 자리는 그 색, 빈 자리는 빈 고리. 안에는 해가 뜨는 그림 ·
//     온전한 해 · 달이 들어 있어 글자 없이 어느 시간대인지 말한다.
//   · 색 고리 — 지금 골라 둔 자리에 넣을 색 다섯. 그 자리에 이미 들어 있는 색은
//     안쪽 고리로 표시되고, **그 색을 한 번 더 누르면 자리가 빈다.**
//     (따로 '비우기' 고리를 뒀더니 색이 아닌 것이 색 사이에 끼어 어색했다)
//
//  자리는 고정이다. 점심을 비워도 저녁이 당겨 오지 않는다.
//
//  글자는 한 자도 쓰지 않는다. 고르는 행위에 문장이 끼어들면 감각이 판단으로 바뀐다.
//

import SwiftUI

struct RadialColorPicker: View {

    typealias Slot = DailyColorLog.Slot

    let palette: ColorPalette
    /// 자리 순서의 HEX. ""는 빈 자리.
    let slotColors: [String]
    /// 처음 골라 둘 자리.
    let initialSlot: Slot
    /// 눌린 칸의 화면상 위치.
    let anchor: CGRect
    /// 화면 경계. 원이 밖으로 나가지 않도록 배치 각도를 고른다.
    let bounds: CGSize

    /// 한 자리에 색을 넣는다. nil이면 비운다.
    let onSet: (Slot, String?) -> Void
    let onDismiss: () -> Void

    @Environment(\.paletteTheme) private var theme
    @State private var unfurled = false
    @State private var selected: Slot

    init(
        palette: ColorPalette,
        slotColors: [String],
        initialSlot: Slot,
        anchor: CGRect,
        bounds: CGSize,
        onSet: @escaping (Slot, String?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.palette = palette
        self.slotColors = slotColors
        self.initialSlot = initialSlot
        self.anchor = anchor
        self.bounds = bounds
        self.onSet = onSet
        self.onDismiss = onDismiss
        _selected = State(initialValue: initialSlot)
    }

    /// 접히는 애니메이션. 펼칠 때는 왼쪽부터 시차를 두지만,
    /// 접힐 때 같은 시차를 주면 색들이 흩어진 채로 사라져 지저분해 보인다.
    /// 되돌아갈 때는 다 같이, 더 빠르게.
    private func collapse() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            unfurled = false
        }
    }

    private func color(of slot: Slot) -> String? {
        let hex = slotColors.indices.contains(slot.index) ? slotColors[slot.index] : ""
        return hex.isEmpty ? nil : hex
    }

    private var swatchSize: CGFloat { max(40, anchor.width * 0.95) }
    private var radius: CGFloat { anchor.width * 1.6 + 8 }
    private var markerSize: CGFloat { max(34, anchor.width * 0.78) }

    /// 원의 중심은 **언제나 누른 칸**이다.
    ///
    /// 처음엔 원 전체가 화면에 들어오도록 중심을 안쪽으로 당겼는데, 가장자리 칸에서
    /// 원이 눈에 띄게 어긋나 '내가 누른 칸에서 나온 것'으로 읽히지 않았다.
    /// 그래서 중심은 고정하고 **배치 각도**만 바꾼다.
    private var center: CGPoint {
        CGPoint(x: anchor.midX, y: anchor.midY)
    }

    // MARK: 색 고리 배치

    /// 각 색이 놓일 각도(라디안).
    ///
    /// 방향을 어림잡지 않는다. 360°를 1°씩 훑어 실제로 화면 안에 들어오는 각도만
    /// 남기고, 그중 가장 긴 연속 구간에 고르게 펼친다. 화면 중앙 쪽으로 부채꼴을
    /// 펴는 방식도 써 봤지만, 7열의 끝 칸처럼 좌우가 다 막힌 자리에서는 부채꼴 끝이
    /// 여전히 화면 밖으로 나갔다.
    private func placement(count: Int) -> (angles: [Double], diameter: CGFloat) {
        guard count > 0 else { return ([], swatchSize) }

        let margin = swatchSize / 2 + 6
        func isInside(_ radians: Double) -> Bool {
            let x = center.x + cos(radians) * radius
            let y = center.y + sin(radians) * radius
            return x >= margin && x <= bounds.width - margin
                && y >= margin && y <= bounds.height - margin
        }

        let inside = (0..<360).map { isInside(Double($0) * .pi / 180) }

        // 사방이 열려 있으면 12시에서 시작하는 온전한 고리.
        if inside.allSatisfy({ $0 }) {
            let step = 2 * Double.pi / Double(count)
            return ((0..<count).map { -Double.pi / 2 + Double($0) * step }, swatchSize)
        }

        // 가장 긴 연속 구간. 0°를 넘어 이어질 수 있으므로 두 바퀴를 훑는다.
        var best = (start: 0, length: 0)
        var cursor = 0
        while cursor < 720 {
            guard inside[cursor % 360] else { cursor += 1; continue }
            var length = 0
            while length < 360 && inside[(cursor + length) % 360] { length += 1 }
            if length > best.length { best = (cursor % 360, length) }
            cursor += max(length, 1)
        }
        guard best.length > 0 else {
            let step = 2 * Double.pi / Double(count)
            return ((0..<count).map { -Double.pi / 2 + Double($0) * step }, swatchSize)
        }

        // 구간 양 끝은 조금 띄운다. 벽에 딱 붙으면 잘린 것처럼 보인다.
        let inset = min(Double(best.length) * 0.12, 18)
        let from = (Double(best.start) + inset) * .pi / 180
        let to = (Double(best.start + best.length) - inset) * .pi / 180
        let step = count > 1 ? (to - from) / Double(count - 1) : 0
        let angles = count > 1
            ? (0..<count).map { from + Double($0) * step }
            : [(from + to) / 2]

        // 좁은 구간에 큰 원을 욱여넣으면 서로 겹친다. 간격에 맞춰 지름을 줄인다.
        let spacing = 2 * radius * sin(abs(step) / 2)
        let diameter = count > 1 ? min(swatchSize, max(26, spacing - 5)) : swatchSize
        return (angles, diameter)
    }

    // MARK: 자리 줄 배치

    /// 세 자리의 중심 좌표. 왼쪽 → 오른쪽이 곧 아침 → 점심 → 저녁.
    ///
    /// 색 고리 바깥 위에 놓는다. 위가 화면 밖이면 아래로 뒤집는다.
    /// 고리보다 안쪽에 두면 색과 자리가 한데 섞여 무엇을 고르는 건지 흐려진다.
    private var markerCenters: [CGPoint] {
        let count = Slot.allCases.count
        // 자리끼리 붙어 있으면 한 덩어리로 보여 셋 중 하나를 고른다는 감각이 흐려진다.
        let gap: CGFloat = 22
        let rowWidth = markerSize * CGFloat(count) + gap * CGFloat(count - 1)
        let clearance = radius + swatchSize / 2 + 16 + markerSize / 2

        let above = center.y - clearance
        let below = center.y + clearance
        let edge = markerSize / 2 + 8
        let y = above >= edge ? above : (below <= bounds.height - edge ? below : above)

        let half = rowWidth / 2
        let midX = min(max(center.x, half + 12), bounds.width - half - 12)
        return (0..<count).map { index in
            CGPoint(
                x: midX - half + markerSize / 2 + CGFloat(index) * (markerSize + gap),
                y: y
            )
        }
    }

    // MARK: 본문

    var body: some View {
        ZStack {
            // 바깥을 누르면 닫힌다. 닫기 버튼을 따로 두지 않는 이유는 글자 없이
            // 설명할 방법이 없기 때문 — 바깥 탭은 설명이 필요 없다.
            // 딤은 배경색이 아니라 검정으로 깐다.
            // 배경색으로 덮으면 밝은 팔레트에서 '흰색 위에 흰색'이라 아무 효과가 없어
            // 색 다섯 개가 허공에 떠 있는 것처럼 보인다.
            // theme.ink(먹빛)도 안 된다 — 어두운 팔레트에서는 크림색이라 화면을
            // 가라앉히는 대신 뿌옇게 바래게 만든다. 어두운 바탕은 이미 어두우므로 조금 더 진하게.
            Rectangle()
                .fill(Color.black.opacity(unfurled ? (theme.colorScheme == .dark ? 0.45 : 0.34) : 0))
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture {
                    collapse()
                    onDismiss()
                }

            // 눌린 칸을 제자리에서 살짝 들어 올린다.
            RoundedRectangle(cornerRadius: anchor.width * 0.22, style: .continuous)
                .fill(theme.surface.opacity(0.001))
                .frame(width: anchor.width, height: anchor.height)
                .overlay {
                    RoundedRectangle(cornerRadius: anchor.width * 0.22, style: .continuous)
                        .strokeBorder(theme.tint, lineWidth: 2)
                }
                // ⚠️ scaleEffect는 반드시 .position보다 **앞**이어야 한다.
                // .position은 뷰를 부모 전체 크기로 부풀리므로, 뒤에 걸면 링이 아니라
                // 화면만 한 뷰가 화면 중심 기준으로 확대된다.
                .scaleEffect(unfurled ? 1.08 : 1)
                .position(x: anchor.midX, y: anchor.midY)
                .animation(.spring(response: 0.34, dampingFraction: 0.7), value: unfurled)
                // 이 표시가 화면을 덮어 바깥 탭(닫기)을 가로채지 않도록.
                .allowsHitTesting(false)

            let points = markerCenters
            // 세 자리를 한 판 위에 올린다. 판이 없으면 뒤의 격자 칸들과 섞여
            // '자리 셋'이 아니라 흩어진 점 셋으로 읽힌다.
            if let first = points.first, let last = points.last {
                Capsule()
                    .fill(theme.surface.opacity(theme.colorScheme == .dark ? 0.7 : 0.9))
                    .overlay { Capsule().strokeBorder(theme.stroke.opacity(0.6), lineWidth: 0.6) }
                    .frame(width: last.x - first.x + markerSize + 22, height: markerSize + 18)
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
                    .opacity(unfurled ? 1 : 0)
                    .scaleEffect(unfurled ? 1 : 0.6)
                    .position(x: (first.x + last.x) / 2, y: first.y)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unfurled)
                    .allowsHitTesting(false)
            }

            ForEach(Array(Slot.allCases.enumerated()), id: \.element) { index, slot in
                marker(slot, at: points[index], index: index)
            }

            let layout = placement(count: palette.swatches.count)
            ForEach(Array(palette.swatches.enumerated()), id: \.element.id) { index, swatch in
                orb(swatch, index: index, layout: layout)
            }
        }
        // 접히기 시작하는 순간부터는 탭을 받지 않는다.
        // 투명해진 배경막이 살아 있으면, 색을 고른 직후 다음 칸을 눌러도
        // 그 탭을 배경막이 삼켜 '아무 일도 없는' 것처럼 보인다.
        .allowsHitTesting(unfurled)
        .sensoryFeedback(.selection, trigger: selected)
        .onAppear { unfurled = true }
    }

    // MARK: 자리

    private func marker(_ slot: Slot, at point: CGPoint, index: Int) -> some View {
        let hex = color(of: slot)
        let fill = hex.flatMap { Color(hex: $0) }
        let isSelected = slot == selected
        let size = markerSize

        return ZStack {
            if let fill {
                Circle().fill(fill)
            } else {
                // 빈 자리. 칸의 '빈 얼굴'과 같은 색에 가는 테두리.
                Circle().fill(theme.surface.opacity(theme.colorScheme == .dark ? 0.55 : 0.92))
                Circle().strokeBorder(theme.inkSecondary.opacity(0.45), lineWidth: 1)
            }

            Image(systemName: slot.symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(symbolColor(on: hex))
        }
        .frame(width: size, height: size)
        // 골라 둔 자리: 틴트 고리를 바깥에 한 겹 두른다.
        .padding(4)
        .overlay {
            Circle()
                .strokeBorder(theme.tint, lineWidth: 2.5)
                .opacity(isSelected ? 1 : 0)
        }
        .scaleEffect(isSelected ? 1.06 : 0.94)
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.08), radius: 8, y: 3)
        .contentShape(.circle)
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selected = slot
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(slot.displayName), \(hex == nil ? "비어 있음" : "\(palette.swatch(for: hex ?? "")?.name ?? "기록된 색")")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        // ⚠️ 탭 영역·접근성은 .position보다 앞이어야 한다. (뒤에 걸면 화면 전체가 된다)
        .opacity(unfurled ? 1 : 0)
        .scaleEffect(unfurled ? 1 : 0.4)
        .position(unfurled ? point : center)
        .animation(
            unfurled
                ? .spring(response: 0.44, dampingFraction: 0.7).delay(0.04 + Double(index) * 0.04)
                : .spring(response: 0.28, dampingFraction: 0.9),
            value: unfurled
        )
    }

    /// 심볼은 바탕색 위에서 읽혀야 한다. 밝은 색 위에는 먹빛, 어두운 색 위에는 흰빛.
    private func symbolColor(on hex: String?) -> Color {
        guard let hex, let c = HexColor.components(from: hex) else {
            return theme.inkSecondary
        }
        let l = c.linear
        let luminance = 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
        return luminance > 0.36 ? Color.black.opacity(0.62) : Color.white.opacity(0.92)
    }

    // MARK: 색 고리

    private func orb(
        _ swatch: ColorSwatch, index: Int, layout: (angles: [Double], diameter: CGFloat)
    ) -> some View {
        let a = layout.angles.indices.contains(index) ? layout.angles[index] : 0
        let size = layout.diameter
        let target = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
        // 이 자리에 이미 들어 있는 색. 한 번 더 누르면 그 자리가 빈다.
        let isCurrent = HexColor.normalized(swatch.hex) == color(of: selected)

        return ZStack {
            Circle().fill(swatch.color)
            // 안쪽에 바탕색 고리를 둘러 '지금 이 자리의 색'임을 표시한다.
            if isCurrent {
                Circle()
                    .strokeBorder(theme.background, lineWidth: max(2.5, size * 0.08))
                    .padding(size * 0.14)
            }
        }
        .frame(width: size, height: size)
        // ⚠️ 탭 영역은 반드시 .position보다 **앞**에 걸어야 한다.
        // .position은 뷰를 부모 전체 크기로 부풀리므로, 뒤에 걸면 탭 영역이
        // 화면만 한 원이 되고 전부 겹쳐 마지막 색만 눌린다.
        .contentShape(.circle)
        .onTapGesture {
            // 색들이 칸으로 되돌아가는 동안 칸은 이미 새 색으로 채워진다.
            collapse()
            // 고른 색을 다시 고르면 고르지 않은 것 — 토글이다.
            onSet(selected, isCurrent ? nil : swatch.hex)
        }
        .accessibilityElement()
        .accessibilityLabel(
            isCurrent
                ? "\(selected.displayName)의 \(swatch.name) 지우기"
                : "\(selected.displayName)에 \(swatch.name) 기록"
        )
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .shadow(color: swatch.color.opacity(0.5), radius: 10, y: 4)
        .scaleEffect(unfurled ? 1 : 0.05)
        .opacity(unfurled ? 1 : 0)
        // 칸 한가운데서 태어나 제자리로 날아간다.
        .position(unfurled ? target : CGPoint(x: anchor.midX, y: anchor.midY))
        .animation(
            unfurled
                ? .spring(response: 0.46, dampingFraction: 0.62)
                    .delay(Double(index) * 0.045)
                : .spring(response: 0.28, dampingFraction: 0.9),
            value: unfurled
        )
        // 자리를 바꾸면 '지금 이 자리의 색' 고리가 다른 색으로 옮겨 간다.
        .animation(.smooth(duration: 0.25), value: selected)
    }
}

#if DEBUG
#Preview("원형 팔레트") {
    @Previewable @State var palette: ColorPalette = .pantone

    GeometryReader { proxy in
        ZStack {
            palette.theme.backgroundGradient.ignoresSafeArea()

            RadialColorPicker(
                palette: palette,
                slotColors: [palette.swatches[0].hex, "", palette.swatches[3].hex],
                initialSlot: .afternoon,
                anchor: CGRect(x: proxy.size.width / 2 - 23, y: proxy.size.height / 2 - 23,
                               width: 46, height: 46),
                bounds: proxy.size,
                onSet: { _, _ in },
                onDismiss: {}
            )
        }
    }
    .paletteTheme(palette)
    .preferredColorScheme(palette.theme.colorScheme)
}
#endif
