//
//  DayDetailSheet.swift
//  colorlog
//
//  곰을 누르면 올라오는 하루 한 장.
//
//   · 위 — 날짜 한 줄. 곰 그림의 손글씨 이름표와 같은 결의 둥근 손글씨체.
//   · 가운데 — 그날의 곰을 크게. 색을 고르면 이 곰 위로 물감이 번진다.
//   · 아래 — 아침 · 점심 · 저녁 세 자리, 그 밑에 팔레트 색 다섯이 한 줄.
//     색을 누르면 골라 둔 자리에 들어가고, 다음 빈 자리로 저절로 넘어간다.
//     자리에 이미 든 색을 한 번 더 누르면 그 자리가 빈다.
//
//  격자에서는 곰이 작아 무슨 동작인지 겨우 보인다. 기록하는 순간만큼은 곰을 크게 보고,
//  고른 색이 곰에 스며드는 걸 지켜볼 수 있게 했다.
//
//  화면의 글자는 날짜뿐이다. 자리는 해 · 달 심볼이, 색은 색 자체가 말한다.
//

import CoreText
import SwiftData
import SwiftUI

struct DayDetailSheet: View {

    typealias Slot = DailyColorLog.Slot

    let date: Date
    let relation: DayRelation
    let palette: ColorPalette
    /// 그날 이미 물어본 자리들. 색을 넣은 뒤 다음에 골라 둘 자리를 정할 때 쓴다.
    let due: [Slot]
    /// 한 자리에 색을 넣는다. nil이면 비운다.
    let onSet: (Slot, String?) -> Void

    @Query private var logs: [DailyColorLog]
    @State private var selected: Slot
    @Environment(\.paletteTheme) private var theme

    init(
        date: Date,
        relation: DayRelation,
        palette: ColorPalette,
        due: [Slot],
        onSet: @escaping (Slot, String?) -> Void
    ) {
        self.date = date
        self.relation = relation
        self.palette = palette
        self.due = due
        self.onSet = onSet
        _logs = Query(filter: DailyColorLog.predicate(for: date))
        // 실제 골라 둘 자리는 기록을 읽은 뒤(onAppear) 정한다.
        _selected = State(initialValue: .morning)
    }

    private var log: DailyColorLog? { logs.first }

    private var slotColors: [String] {
        log?.slotColors ?? Array(repeating: "", count: DailyColorLog.maxColorsPerDay)
    }

    private func color(of slot: Slot) -> String? {
        let hex = slotColors[slot.index]
        return hex.isEmpty ? nil : hex
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(.colorLog)))
                .font(.gaegu(size: 30))
                .foregroundStyle(theme.ink)
                .padding(.top, 34)

            Spacer(minLength: 12)

            // 발 아래로 여유를 남긴다. 오늘의 곰은 이웃보다 한 치수 커서 위로 자란다.
            DayBearCell(
                date: date, colors: slotColors, relation: relation, pose: log?.pose,
                isHighlighted: relation == .today, usesSnapshot: false)
                .frame(width: 184, height: 184)

            Spacer(minLength: 12)

            slotRow
                .padding(.bottom, 20)

            colorRow
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
        .sensoryFeedback(.selection, trigger: selected)
        .onAppear {
            selected = Slot.defaultSelection(slotColors: slotColors, due: due)
        }
    }

    // MARK: 자리

    private var slotRow: some View {
        HStack(spacing: 18) {
            ForEach(Slot.allCases, id: \.self) { slot in
                marker(slot)
            }
        }
    }

    private func marker(_ slot: Slot) -> some View {
        let hex = color(of: slot)
        let isSelected = slot == selected
        let size: CGFloat = 34

        return ZStack {
            if let hex {
                Circle().fill(Color(hex: hex, fallback: .gray))
            } else {
                Circle().fill(theme.surface.opacity(theme.colorScheme == .dark ? 0.55 : 0.92))
                Circle().strokeBorder(theme.inkSecondary.opacity(0.45), lineWidth: 1)
            }
            Image(systemName: slot.symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(symbolColor(on: hex))
        }
        .frame(width: size, height: size)
        // 골라 둔 자리: 바깥에 틴트 고리 한 겹.
        .padding(4)
        .overlay {
            Circle()
                .strokeBorder(theme.tint, lineWidth: 2.5)
                .opacity(isSelected ? 1 : 0)
        }
        .scaleEffect(isSelected ? 1.06 : 0.94)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        .contentShape(.circle)
        .onTapGesture { selected = slot }
        .accessibilityElement()
        .accessibilityLabel("\(slot.displayName), \(hex.flatMap { palette.swatch(for: $0)?.name } ?? (hex == nil ? "비어 있음" : "기록된 색"))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// 심볼은 바탕색 위에서 읽혀야 한다. 밝은 색 위에는 먹빛, 어두운 색 위에는 흰빛.
    private func symbolColor(on hex: String?) -> Color {
        guard let hex, let c = HexColor.components(from: hex) else { return theme.inkSecondary }
        let l = c.linear
        let luminance = 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
        return luminance > 0.36 ? Color.black.opacity(0.62) : Color.white.opacity(0.92)
    }

    // MARK: 색

    private var colorRow: some View {
        HStack(spacing: 14) {
            ForEach(palette.swatches) { swatch in
                orb(swatch)
            }
        }
    }

    private func orb(_ swatch: ColorSwatch) -> some View {
        // 골라 둔 자리에 이미 든 색. 한 번 더 누르면 그 자리가 빈다.
        let isCurrent = HexColor.normalized(swatch.hex) == color(of: selected)

        return Button { pick(swatch, isCurrent: isCurrent) } label: {
            ZStack {
                Circle().fill(swatch.color)
                if isCurrent {
                    Circle()
                        .strokeBorder(theme.background, lineWidth: 3.5)
                        .padding(7)
                }
            }
            .frame(width: 50, height: 50)
        }
        .buttonStyle(OrbPressStyle())
        .animation(.smooth(duration: 0.25), value: isCurrent)
        .accessibilityLabel(isCurrent
            ? "\(selected.displayName)의 \(swatch.name) 지우기"
            : "\(selected.displayName)에 \(swatch.name) 기록")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func pick(_ swatch: ColorSwatch, isCurrent: Bool) {
        let hex = isCurrent ? nil : swatch.hex
        onSet(selected, hex)
        guard hex != nil else { return }

        // 색을 넣었으면 다음 빈 자리로 넘어가 둔다. 세 자리가 다 찼으면 그대로.
        var next = slotColors
        next[selected.index] = HexColor.normalized(swatch.hex) ?? swatch.hex
        let following = Slot.defaultSelection(slotColors: next, due: due)
        if next[following.index].isEmpty {
            selected = following
        }
    }
}

/// 누르는 동안 살짝 눌려 들어가는 색 알.
private struct OrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 손글씨체

extension Font {
    /// 둥근 손글씨체 Gaegu(SIL Open Font License, `Resources/Fonts/Gaegu-OFL.txt`).
    /// 시스템에는 귀여운 한글 서체가 없어 앱에 싣는다. Info.plist 대신 처음 쓸 때 등록한다.
    static func gaegu(size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        _ = GaeguFont.registered
        return .custom(GaeguFont.postScriptName, size: size, relativeTo: style)
    }
}

private enum GaeguFont {
    static let postScriptName = "Gaegu-Bold"

    static let registered: Bool = {
        guard let url = Bundle.main.url(forResource: "Gaegu-Bold", withExtension: "ttf") else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()
}

// MARK: - 미리보기

#Preview("하루 한 장") {
    @Previewable @State var isPresented = true
    let container = ColorLogStore.inMemory()
    let palette = ColorPalette.default
    let today = Calendar.current.startOfDay(for: .now)
    let log = DailyColorLog(date: today, colors: [palette.swatches[0].hex, "", ""], palette: palette)
    container.mainContext.insert(log)

    return Button("열기") { isPresented = true }
        .sheet(isPresented: $isPresented) {
            DayDetailSheet(date: today, relation: .today, palette: palette, due: [.morning, .afternoon]) { slot, hex in
                _ = try? container.mainContext.setColor(hex, for: slot, on: today, palette: palette)
            }
        }
        .modelContainer(container)
}
