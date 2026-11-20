//
//  OnboardingView.swift
//  colorlog
//
//  처음 연 사람에게 건네는 곰 세 장. 주인공은 곰이고, 글은 한 장에 두 줄을 넘지 않는다.
//
//   1. 하루 세 번 — 하늘이 아침 → 점심 → 저녁으로 바뀌며 곰이 색 셋으로 물든다.
//   2. 물감 고르기 — 팔레트를 누르면 곰이 그 색으로 다시 번진다.
//   3. 곰이 물어볼게요 — 알림 시각을 보여 주고, 여기서 알림 권한을 묻는다.
//
//  앱 화면에는 문장을 올리지 않는다는 원칙(TimelineGridView)은 그대로다. 이 세 장은
//  한 번 보고 지나가는 안내라 예외로 둔다. 건너뛰어도 아무것도 잃지 않는다 —
//  팔레트와 알림은 설정에서 언제든 바꿀 수 있다.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {

    /// `Palette.id`. 두 번째 장에서 고르면 바로 앱 전체 팔레트가 된다.
    @Binding var paletteID: String
    /// 끝났다(마지막 장의 버튼 또는 건너뛰기).
    let onFinish: () -> Void

    @Environment(\.paletteTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page: Page = .threeTimes
    @State private var isRequesting = false

    private let reminders = ReminderStore.shared

    enum Page: Int, CaseIterable, Identifiable {
        case threeTimes, palette, reminders
        var id: Int { rawValue }
    }

    private var palette: Palette { Palette.resolve(paletteID) }

    /// 큰 글자에서는 곰을 줄여 글과 버튼이 화면 안에 남게 한다.
    private var bearSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 150 : 220 }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $page) {
                ThreeTimesPage(palette: palette, bearSize: bearSize)
                    .tag(Page.threeTimes)
                PalettePage(paletteID: $paletteID, bearSize: bearSize)
                    .tag(Page.palette)
                RemindersPage(reminders: reminders.reminders, bearSize: bearSize)
                    .tag(Page.reminders)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, 14)

            bottomButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .background(theme.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: page)
        .task { await reminders.refreshAuthorization() }
    }

    // MARK: 위 · 아래

    private var topBar: some View {
        HStack {
            Spacer()
            if page != .reminders {
                Button("건너뛰기", action: finish)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(theme.ink.opacity(0.7))
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.horizontal, 12)
                    .accessibilityHint("안내를 닫고 바로 시작해요")
            }
        }
        .frame(minHeight: 44)
        .padding(.top, 4)
    }

    /// 몇 번째 장인지. 점은 틴트 대신 먹빛으로 — 틴트가 옅은 팔레트에서도 보이게.
    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(Page.allCases) { item in
                Capsule()
                    .fill(item == page ? theme.ink.opacity(0.75) : theme.inkSecondary.opacity(0.35))
                    .frame(width: item == page ? 18 : 7, height: 7)
            }
        }
        .animation(.smooth(duration: 0.3), value: page)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "\(page.rawValue + 1)/\(Page.allCases.count)쪽", comment: "온보딩 쪽 번호"))
    }

    @ViewBuilder
    private var bottomButtons: some View {
        switch page {
        case .threeTimes, .palette:
            primaryButton(String(localized: "다음")) {
                withAnimation(.smooth(duration: 0.35)) {
                    page = Page(rawValue: page.rawValue + 1) ?? .reminders
                }
            }
        case .reminders:
            VStack(spacing: 6) {
                if reminders.authorization == .notDetermined {
                    primaryButton(String(localized: "알림 받기")) {
                        requestNotifications()
                    }
                    .disabled(isRequesting)
                    Button("나중에 할게요", action: finish)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(theme.ink.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityHint("알림은 설정에서 언제든 켤 수 있어요")
                } else {
                    primaryButton(String(localized: "시작하기"), action: finish)
                }
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.background)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(theme.ink, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: 동작

    /// 시스템 권한 창을 띄운다. 허락하든 거절하든 안내는 끝난다 — 답을 했으니까.
    private func requestNotifications() {
        isRequesting = true
        Task {
            await reminders.requestAuthorization()
            isRequesting = false
            finish()
        }
    }

    private func finish() {
        OnboardingPolicy.markCompleted()
        onFinish()
    }
}

// MARK: - 공용 글 블록

/// 한 장의 제목과 한 줄 설명. 제목은 곰 이름표와 같은 손글씨체.
private struct PageCaption: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    @Environment(\.paletteTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.gaegu(size: 32, relativeTo: .title))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.body)
                .foregroundStyle(theme.ink.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 28)
    }
}

/// 장마다 내용이 길어지면(큰 글자) 스크롤되게 감싼다.
private struct PageScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    content
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - 1. 하루 세 번

/// 하늘이 아침 → 점심 → 저녁으로 흐르는 동안 곰이 색 하나씩 물든다. 다 물들면 만세.
private struct ThreeTimesPage: View {
    let palette: Palette
    let bearSize: CGFloat

    @Environment(\.paletteTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 칠한 자리 수(0...3).
    @State private var filled = 0

    private var slots: [DailyColorLog.Slot] { DailyColorLog.Slot.allCases }

    /// 연출에 쓸 세 색. 팔레트 앞쪽 셋.
    private var colors: [ColorSwatch] { Array(palette.swatches.prefix(3)) }

    /// 지금 하늘의 시각. 칠한 자리를 따라 아침 · 점심 · 저녁으로.
    private var skyDate: Date {
        let hours = [8.5, 13.0, 20.5]
        let index = max(0, min(filled, 3) - 1)
        let start = Calendar.current.startOfDay(for: .now)
        return start.addingTimeInterval(hours[filled == 0 ? 0 : index] * 3600)
    }

    var body: some View {
        PageScroll {
            ZStack {
                SkyView(theme: theme, date: skyDate)
                    .clipShape(.rect(cornerRadius: 36, style: .continuous))
                    .animation(.smooth(duration: 1.0), value: filled)
                WatercolorBearView(
                    moodColors: colors.prefix(filled).map(\.color),
                    pose: filled >= 3 ? .cheering : .sitting,
                    style: filled == 0 ? .bare : .painted,
                    seed: 0xC0_1B_EA,
                    bloomsOnAppear: false
                )
                .frame(width: bearSize * 0.82, height: bearSize * 0.82)
            }
            .frame(width: bearSize, height: bearSize)
            .accessibilityElement()
            .accessibilityLabel("아침, 점심, 저녁 색으로 물드는 곰")

            slotRow

            PageCaption(
                title: "하루 세 번,\n지금 마음의 색을 골라요",
                message: "아침 · 점심 · 저녁, 고른 색이 곰에게 스며들어요. 색의 뜻은 내가 정해요."
            )
        }
        .task { await play() }
    }

    /// 해 · 해 · 달 자리. 칠한 자리는 그 색으로 찬다.
    private var slotRow: some View {
        HStack(spacing: 18) {
            ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                let swatch = index < filled ? colors[safe: index] : nil
                ZStack {
                    Circle()
                        .fill(swatch?.color ?? theme.surface)
                        .swatchOutline(hex: swatch?.hex ?? "")
                    if swatch == nil {
                        Circle().strokeBorder(theme.inkSecondary.opacity(0.45), lineWidth: 1)
                    }
                    Image(systemName: slot.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(swatch == nil ? theme.inkSecondary : .white.opacity(0.92))
                        .shadow(color: .black.opacity(swatch == nil ? 0 : 0.25), radius: 1)
                }
                .frame(width: 38, height: 38)
                .animation(.smooth(duration: 0.4), value: filled)
            }
        }
        .accessibilityHidden(true)
    }

    /// 색 하나씩 → 잠깐 만세 → 처음부터. 동작 줄이기를 켰으면 다 칠한 곰 한 장으로 멈춰 둔다.
    private func play() async {
        guard !reduceMotion else { filled = 3; return }
        while !Task.isCancelled {
            for step in 0...3 {
                withAnimation(.smooth(duration: 0.6)) { filled = step }
                try? await Task.sleep(for: .milliseconds(step == 3 ? 2400 : 1300))
                if Task.isCancelled { return }
            }
        }
    }
}

// MARK: - 2. 물감 고르기

private struct PalettePage: View {
    @Binding var paletteID: String
    let bearSize: CGFloat

    @Environment(\.paletteTheme) private var theme

    /// 처음 온 사람에게는 기본 팔레트 열 개만. 직접 만들기는 설정에서.
    private var presets: [Palette] { ColorPalette.allCases.map { Palette(preset: $0) } }
    private var selected: Palette { Palette.resolve(paletteID) }

    var body: some View {
        PageScroll {
            WatercolorBearView(
                moodColors: selected.swatches.prefix(3).map(\.color),
                pose: .painting,
                style: .painted,
                seed: 0xC0_1B_EB
            )
            // 팔레트가 바뀌면 곰이 새 물감으로 다시 번진다.
            .id(selected.id)
            .frame(width: bearSize * 0.8, height: bearSize * 0.8)
            .accessibilityElement()
            .accessibilityLabel(String(localized: "\(selected.name) 물감으로 칠한 곰", comment: "온보딩 곰 VoiceOver. 팔레트 이름"))

            PageCaption(
                title: "마음에 드는 물감을 골라요",
                message: "나중에 설정에서 바꾸거나 직접 만들 수 있어요."
            )

            VStack(spacing: 10) {
                ForEach(presets) { palette in
                    PaletteChoiceRow(palette: palette, isSelected: palette.id == selected.id) {
                        withAnimation(.smooth(duration: 0.4)) { paletteID = palette.id }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

/// 팔레트 한 줄: 이름 + 색 알. 이름이 있어 VoiceOver와 큰 글자에서도 고를 수 있다.
private struct PaletteChoiceRow: View {
    let palette: Palette
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.paletteTheme) private var theme

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    name
                    Spacer(minLength: 8)
                    chips
                }
                VStack(alignment: .leading, spacing: 8) {
                    name
                    chips
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(theme.surface.opacity(isSelected ? 1 : 0.6), in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? theme.ink.opacity(0.7) : theme.stroke, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(palette.name)
        .accessibilityValue(palette.swatches.map(\.name).joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var name: some View {
        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
            }
            Text(palette.name)
                .font(.body.weight(isSelected ? .semibold : .regular))
        }
        .foregroundStyle(theme.ink)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(palette.swatches) { swatch in
                Circle()
                    .fill(swatch.color)
                    .frame(width: 22, height: 22)
                    .swatchOutline(hex: swatch.hex, on: HexColor.lightOrDarkSurface(for: theme))
            }
        }
    }
}

// MARK: - 3. 곰이 물어볼게요

private struct RemindersPage: View {
    let reminders: [Reminder]
    let bearSize: CGFloat

    @Environment(\.paletteTheme) private var theme

    var body: some View {
        PageScroll {
            WatercolorBearView(
                moodColors: [],
                pose: .waving,
                style: .bare,
                seed: 0xC0_1B_EC,
                bloomsOnAppear: false
            )
            .frame(width: bearSize * 0.8, height: bearSize * 0.8)
            .accessibilityHidden(true)

            PageCaption(
                title: "때가 되면 곰이 물어볼게요",
                message: "\"지금, 어떤 색인가요?\" 알림을 누르면 바로 그 자리가 열려요."
            )

            VStack(spacing: 0) {
                ForEach(reminders) { reminder in
                    HStack(spacing: 14) {
                        Image(systemName: reminder.slot.symbolName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.ink.opacity(0.75))
                            .frame(minWidth: 26)
                        Text(reminder.slot.displayName)
                            .font(.body)
                            .foregroundStyle(theme.ink)
                        Spacer(minLength: 8)
                        Text(reminder.time, format: .dateTime.hour().minute())
                            .font(.body.monospacedDigit())
                            .foregroundStyle(theme.ink.opacity(0.75))
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    if reminder.slot != DailyColorLog.Slot.allCases.last {
                        Rectangle().fill(theme.stroke).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(theme.surface.opacity(0.75), in: .rect(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)

            Label {
                Text("홈 화면에 위젯을 두면 앱을 열지 않고도 색을 고를 수 있어요.")
            } icon: {
                Image(systemName: "square.grid.2x2")
            }
            .font(.footnote)
            .foregroundStyle(theme.ink.opacity(0.7))
            .padding(.horizontal, 32)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 도움

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension HexColor {
    /// 온보딩 카드 바탕(surface)에 가까운 HEX. 대비 판단용.
    static func lightOrDarkSurface(for theme: PaletteTheme) -> String {
        theme.colorScheme == .dark ? "#1E1E21" : "#F4F3F1"
    }
}

// MARK: - 미리보기

#Preview("첫 실행 안내") {
    @Previewable @State var paletteID = Palette.default.id
    OnboardingView(paletteID: $paletteID, onFinish: {})
        .paletteTheme(Palette.resolve(paletteID))
}
