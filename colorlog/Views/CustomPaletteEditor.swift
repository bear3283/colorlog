//
//  CustomPaletteEditor.swift
//  colorlog
//
//  나만의 팔레트를 만드는 시트.
//
//   · 위 — 지금 다섯 색으로 칠한 곰. 손잡이를 움직이는 대로 곰의 색이 바뀐다.
//     색은 결국 곰 위에 번질 물감이니, 동그라미가 아니라 곰을 보고 고르게 한다.
//   · 가운데 — 다섯 색 동그라미. 누른 색이 고치는 색이 된다.
//   · 아래 — 손잡이 두 개.
//       색상: 무지개 띠 위에서 색을 고른다.
//       진하기: 물을 잔뜩 탄 옅은 색에서 물감이 고인 진한 색까지.
//     수채 물감을 섞는 감각 그대로다. 밝기 · 채도를 따로 만지는 것보다 덜 헷갈린다.
//     그 옆에 시스템 색상 선택기(스펙트럼 · 스포이트)와 '수채 곰으로 되돌리기'.
//
//  글자는 없다. 손잡이와 동그라미에는 VoiceOver 레이블과 조절 동작을 붙였다.
//

import SwiftUI
import UIKit
import WidgetKit

struct CustomPaletteEditor: View {

    @AppStorage(CustomPalette.key, store: ColorLogStore.defaults) private var stored = ""
    @Environment(\.paletteTheme) private var theme

    @State private var selected = 0
    @State private var hue: Double = 0
    @State private var depth: Double = 0.6

    private var hexes: [String] { CustomPalette.decode(stored) }

    var body: some View {
        VStack(spacing: 0) {
            WatercolorBearView(
                moodColors: hexes.map { Color(hex: $0, fallback: .gray) },
                pose: .standing,
                seed: 0xC0_FFEE,
                bloomsOnChange: false)
                .frame(width: 176, height: 176)
                .padding(.top, 34)
                .accessibilityHidden(true)

            Spacer(minLength: 18)

            swatchRow
                .padding(.bottom, 26)

            VStack(spacing: 22) {
                PaintSlider(
                    value: hue / 360,
                    track: (0...12).map { Color(hex: CustomPalette.color(hue: Double($0) * 30, depth: depth), fallback: .gray) },
                    thumb: currentColor,
                    label: "색상",
                    onChange: { hue = $0 * 360; apply() })

                PaintSlider(
                    value: depth,
                    track: [0, 0.5, 1].map { Color(hex: CustomPalette.color(hue: hue, depth: $0), fallback: .gray) },
                    thumb: currentColor,
                    label: "진하기",
                    onChange: { depth = $0; apply() })
            }
            .padding(.horizontal, 6)

            HStack(spacing: 28) {
                // 정확한 색을 원할 때. 시스템 선택기에는 스펙트럼 · 슬라이더 · 스포이트가 있다.
                ColorPicker(
                    "\(selected + 1)번째 색 직접 고르기",
                    selection: Binding(
                        get: { currentColor },
                        set: { pickExact($0) }),
                    supportsOpacity: false)
                    .labelsHidden()

                Button {
                    withAnimation(.smooth(duration: 0.35)) {
                        stored = CustomPalette.encode(CustomPalette.defaultHexes)
                    }
                    loadHandles()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.inkSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("수채 곰 색으로 되돌리기")
            }
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
        .sensoryFeedback(.selection, trigger: selected)
        .onAppear {
            // 처음 열 때 저장된 값이 없으면 기본 다섯 색을 적어 둔다. 위젯도 같은 색을 보게.
            if stored.isEmpty { stored = CustomPalette.encode(CustomPalette.defaultHexes) }
            loadHandles()
        }
        // 손잡이를 끄는 동안 위젯을 매번 다시 그리지 않는다. 닫을 때 한 번.
        .onDisappear { WidgetCenter.shared.reloadAllTimelines() }
    }

    private var currentColor: Color { Color(hex: hexes[selected], fallback: .gray) }

    // MARK: 다섯 색

    private var swatchRow: some View {
        HStack(spacing: 14) {
            ForEach(0..<5, id: \.self) { index in
                let isSelected = index == selected
                Circle()
                    .fill(Color(hex: hexes[index], fallback: .gray))
                    .frame(width: 46, height: 46)
                    .padding(4)
                    .overlay {
                        Circle()
                            .strokeBorder(theme.tint, lineWidth: 2.5)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .scaleEffect(isSelected ? 1.06 : 0.94)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
                    .contentShape(.circle)
                    .onTapGesture {
                        selected = index
                        loadHandles()
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(index + 1)번째 색")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    // MARK: 손잡이

    private func loadHandles() {
        let handles = CustomPalette.handles(for: hexes[selected])
        hue = handles.hue
        depth = handles.depth
    }

    private func apply() {
        write(CustomPalette.color(hue: hue, depth: depth))
    }

    private func pickExact(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        write(String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b)))
        loadHandles()
    }

    private func write(_ hex: String) {
        var next = hexes
        next[selected] = hex
        stored = CustomPalette.encode(next)
    }
}

/// 둥근 띠 위의 손잡이 하나. 띠 자체가 고를 수 있는 색을 보여 준다.
private struct PaintSlider: View {
    /// 0~1.
    let value: Double
    let track: [Color]
    let thumb: Color
    let label: String
    let onChange: (Double) -> Void

    @Environment(\.paletteTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let knob: CGFloat = 30

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: track, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 14)
                    .frame(maxHeight: .infinity)

                Circle()
                    .fill(thumb)
                    .overlay { Circle().strokeBorder(theme.background, lineWidth: 4) }
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .frame(width: knob, height: knob)
                    .offset(x: (width - knob) * value)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        onChange(min(max((drag.location.x - knob / 2) / (width - knob), 0), 1))
                    }
            )
        }
        .frame(height: 34)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((value * 100).rounded()))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(value + 0.05, 1))
            case .decrement: onChange(max(value - 0.05, 0))
            @unknown default: break
            }
        }
    }
}

#Preview("나만의 팔레트") {
    @Previewable @State var isPresented = true
    Button("열기") { isPresented = true }
        .sheet(isPresented: $isPresented) { CustomPaletteEditor() }
        .paletteTheme(.custom)
}
