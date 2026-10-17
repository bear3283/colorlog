//
//  PaletteEditor.swift
//  colorlog
//
//  팔레트의 색을 고치는 시트. 사용자 팔레트와 프리셋을 같은 화면에서 고친다.
//
//   · 위 — 지금 색으로 칠한 곰. 손잡이를 움직이는 대로 곰의 색이 바뀐다.
//     색은 결국 곰 위에 번질 물감이니, 동그라미가 아니라 곰을 보고 고르게 한다.
//   · 가운데 — 색 동그라미 3~7개. 누른 색이 고치는 색이 된다.
//     끝의 ＋로 색을 더하고, 동그라미를 길게 눌러 뺀다.
//   · 아래 — 손잡이 두 개.
//       색상: 무지개 띠 위에서 색을 고른다.
//       진하기: 물을 잔뜩 탄 옅은 색에서 물감이 고인 진한 색까지.
//     수채 물감을 섞는 감각 그대로다. 밝기 · 채도를 따로 만지는 것보다 덜 헷갈린다.
//   · 맨 아래 — 시스템 색상 선택기(스펙트럼 · 스포이트), 그리고
//       프리셋이면 '원래 색으로'(고쳤을 때만), 사용자 팔레트면 '이 팔레트 지우기'.
//
//  글자는 없다. 손잡이와 동그라미에는 VoiceOver 레이블과 조절 동작을 붙였다.
//

import SwiftUI
import UIKit
import WidgetKit

struct PaletteEditor: View {

    /// 고치는 팔레트의 `Palette.id`.
    let paletteID: String
    /// 사용자 팔레트를 지운 뒤. 선택값 정리는 부르는 쪽이 맡는다. 시트는 스스로 닫힌다.
    var onDelete: () -> Void = {}

    // 저장소가 바뀌면 다시 그리도록 지켜본다. 값은 `Palette.resolve`가 읽는다.
    @AppStorage(PaletteStore.userPalettesKey, store: ColorLogStore.defaults) private var userPalettesData = Data()
    @AppStorage(PaletteStore.presetOverridesKey, store: ColorLogStore.defaults) private var overridesData = Data()
    @Environment(\.paletteTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selected = 0
    @State private var hue: Double = 0
    @State private var depth: Double = 0.6
    @State private var isConfirmingDelete = false

    private var palette: Palette {
        _ = (userPalettesData, overridesData)
        return Palette.resolve(paletteID)
    }

    private var hexes: [String] { palette.swatches.map(\.hex) }

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
                    track: (0...12).map { Color(hex: PaintMix.color(hue: Double($0) * 30, depth: depth), fallback: .gray) },
                    thumb: currentColor,
                    label: "색상",
                    onChange: { hue = $0 * 360; apply() })

                PaintSlider(
                    value: depth,
                    track: [0, 0.5, 1].map { Color(hex: PaintMix.color(hue: hue, depth: $0), fallback: .gray) },
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

                trailingAction
            }
            .frame(height: 44)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.impact(weight: .light), trigger: hexes.count)
        .onAppear(perform: loadHandles)
        // 손잡이를 끄는 동안 위젯을 매번 다시 그리지 않는다. 닫을 때 한 번.
        .onDisappear { WidgetCenter.shared.reloadAllTimelines() }
    }

    private var currentHex: String { hexes[min(selected, hexes.count - 1)] }
    private var currentColor: Color { Color(hex: currentHex, fallback: .gray) }

    // MARK: 원래대로 · 지우기

    @ViewBuilder
    private var trailingAction: some View {
        switch palette.source {
        case .preset(let preset):
            // 고치지 않은 프리셋에는 되돌릴 것이 없다. 자리는 남겨 두어 선택기가 흔들리지 않게.
            actionButton("arrow.counterclockwise", label: "원래 색으로 되돌리기", color: theme.inkSecondary) {
                withAnimation(.smooth(duration: 0.35)) { PaletteStore.resetPreset(preset) }
                selected = min(selected, preset.swatches.count - 1)
                loadHandles()
            }
            .opacity(palette.isModifiedPreset ? 1 : 0)
            .disabled(!palette.isModifiedPreset)
        case .user:
            actionButton("trash", label: "이 팔레트 지우기", color: theme.inkSecondary) {
                isConfirmingDelete = true
            }
            // 휴지통에 붙여 두어야 확인 풍선이 휴지통을 가리킨다.
            .confirmationDialog("\(palette.name)을 지울까요?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("지우기", role: .destructive, action: deletePalette)
            } message: {
                Text("이미 칠한 날의 색은 그대로 남아요.")
            }
        }
    }

    private func actionButton(_ symbol: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }

    private func deletePalette() {
        guard case .user(let id) = palette.source else { return }
        onDelete()
        PaletteStore.deletePalette(id: id)
        dismiss()
    }

    // MARK: 색 동그라미

    private var canAdd: Bool { hexes.count < PaletteStore.colorRange.upperBound }
    private var canRemove: Bool { hexes.count > PaletteStore.colorRange.lowerBound }

    private var swatchRow: some View {
        // 일곱 색에 ＋까지 한 줄에 들어가도록 개수에 맞춰 동그라미를 줄인다.
        GeometryReader { proxy in
            let count = CGFloat(hexes.count + (canAdd ? 1 : 0))
            let spacing: CGFloat = count > 6 ? 8 : 14
            let size = min(46, (proxy.size.width - spacing * (count - 1)) / count - 8)

            HStack(spacing: spacing) {
                ForEach(Array(hexes.enumerated()), id: \.offset) { index, hex in
                    swatch(index: index, hex: hex, size: size)
                        .transition(.scale.combined(with: .opacity))
                }
                if canAdd {
                    addButton(size: size)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: hexes.count)
        }
        .frame(height: 58)
    }

    private func swatch(index: Int, hex: String, size: CGFloat) -> some View {
        let isSelected = index == selected
        return Circle()
            .fill(Color(hex: hex, fallback: .gray))
            .frame(width: size, height: size)
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
            // 길게 누르면 뺀다. 메뉴를 한 번 거쳐 실수로 지우지 않게.
            .contextMenu {
                if canRemove {
                    Button("이 색 빼기", systemImage: "minus.circle", role: .destructive) { removeColor(at: index) }
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(index + 1)번째 색")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityActions {
                if canRemove {
                    Button("이 색 빼기") { removeColor(at: index) }
                }
            }
    }

    private func addButton(size: CGFloat) -> some View {
        Button(action: addColor) {
            Circle()
                .strokeBorder(theme.inkSecondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(theme.inkSecondary)
                }
                .padding(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("색 더하기")
    }

    /// 마지막 색에서 색상을 60° 돌린 색을 같은 진하기로 더한다. 곰에 바로 보이는 색이라
    /// 거기서부터 손잡이로 고르면 된다.
    private func addColor() {
        guard canAdd, let last = hexes.last else { return }
        let handles = PaintMix.handles(for: last)
        withAnimation { PaletteStore.setHexes(hexes + [PaintMix.color(hue: handles.hue + 60, depth: handles.depth)], for: paletteID) }
        selected = hexes.count - 1
        loadHandles()
    }

    private func removeColor(at index: Int) {
        guard canRemove, hexes.indices.contains(index) else { return }
        var next = hexes
        next.remove(at: index)
        withAnimation { PaletteStore.setHexes(next, for: paletteID) }
        selected = min(selected, next.count - 1)
        loadHandles()
    }

    // MARK: 손잡이

    private func loadHandles() {
        let handles = PaintMix.handles(for: currentHex)
        hue = handles.hue
        depth = handles.depth
    }

    private func apply() {
        write(PaintMix.color(hue: hue, depth: depth))
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
        guard next.indices.contains(selected) else { return }
        next[selected] = hex
        PaletteStore.setHexes(next, for: paletteID)
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
        .sheet(isPresented: $isPresented) { PaletteEditor(paletteID: ColorPalette.watercolor.rawValue) }
        .paletteTheme(.watercolor)
}
