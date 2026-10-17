//
//  SettingsView.swift
//  colorlog
//
//  설정에도 문장이 없다.
//
//  글을 지우는 것이 아니라, 같은 뜻을 **다른 것이 지게** 만드는 일이었다.
//   · 팔레트 → 그 팔레트로 칠해진 카드 자체가 설명이다
//   · 홈 화면 아이콘 → 실제 아이콘 그림이 레이블이다
//   · 알림 시간 → 해·달 심볼이 아침·점심·저녁을 가리킨다
//   · 알림 권한 → 종 하나
//
//  남은 글자는 시각 숫자(오전 8:00)뿐이다. 그건 문장이 아니라 값이고,
//  숫자 없이 시간을 고를 방법은 없다.
//  대신 모든 요소에 VoiceOver 레이블을 붙여 소리로는 전부 읽히게 했다.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {

    /// `Palette.id`. @AppStorage와 직접 연결된다.
    @Binding var selection: String
    /// 홈 화면 아이콘을 팔레트에 맞출지.
    @Binding var syncsAppIcon: Bool

    @Environment(\.paletteTheme) private var theme
    @Environment(\.openURL) private var openURL
    // 사용자 팔레트 · 고친 프리셋. 편집기에서 바뀌면 카드도 따라 다시 그려진다.
    @AppStorage(PaletteStore.userPalettesKey, store: ColorLogStore.defaults) private var userPalettesData = Data()
    @AppStorage(PaletteStore.presetOverridesKey, store: ColorLogStore.defaults) private var overridesData = Data()
    /// 편집기로 고치고 있는 팔레트.
    @State private var editing: EditingPalette?

    private let reminders = ReminderStore.shared

    private var selected: Palette { Palette.resolve(selection) }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                palettes
                divider
                appIconRow
                divider
                reminderGroup
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 44)
        }
        .task { await reminders.refreshAuthorization() }
        // 바탕은 격자와 같은 흰 종이(다크 모드에서는 먹빛).
        .background(theme.background)
        .presentationBackground(theme.background)
        .scrollIndicators(.hidden)
        // 닫기 버튼은 두지 않는다. 첫 팔레트 카드와 겹치는 데다,
        // 시트는 아래로 쓸어내려 닫는 게 이미 몸에 익은 동작이다.
        // 시스템 그래버가 그 사실을 글자 없이 알려 준다.
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.stroke)
            .frame(height: 1)
            .padding(.horizontal, 40)
    }

    // MARK: 팔레트

    private var palettes: some View {
        _ = (userPalettesData, overridesData)
        return VStack(spacing: 14) {
            ForEach(Palette.all) { palette in
                PaletteCard(
                    palette: palette,
                    isSelected: palette.id == selected.id,
                    action: {
                        withAnimation(.smooth(duration: 0.45)) {
                            selection = palette.id
                        }
                    },
                    onEdit: palette.source.isUser ? { openEditor(for: palette) } : nil
                )
                // 카드는 저장된 색을 읽어 그린다. 색이 바뀌면 새로 그린다.
                .id(palette.id + palette.swatches.map(\.hex).joined())
            }
        }
        .sheet(item: $editing) { item in
            CustomPaletteEditor(paletteID: item.id)
                .paletteTheme(Palette.resolve(item.id))
                .environment(\.locale, .colorLog)
        }
    }

    /// 붓을 누르면 그 팔레트로 바꾸고 편집기를 연다. 고치는 색이 곧 캔버스의 색이 되도록.
    private func openEditor(for palette: Palette) {
        withAnimation(.smooth(duration: 0.45)) { selection = palette.id }
        editing = EditingPalette(id: palette.id)
    }

    // MARK: 홈 화면 아이콘

    /// 아이콘 그림 자체가 "홈 화면 아이콘"이라는 말을 대신한다.
    private var appIconRow: some View {
        HStack(spacing: 18) {
            AppIconView(palette: selected)
                .frame(width: 60, height: 60)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
                // 탈색시키면 레이블 역할을 하는 그림 자체가 안 읽힌다.
                // 꺼진 상태는 밝기로만 말한다.
                .opacity(syncsAppIcon ? 1 : 0.4)
                .animation(.smooth(duration: 0.3), value: syncsAppIcon)
                .animation(.smooth(duration: 0.3), value: selected)

            Spacer(minLength: 0)

            Toggle("홈 화면 아이콘을 팔레트에 맞추기", isOn: $syncsAppIcon)
                .labelsHidden()
                .tint(theme.tint)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .settingsCard(theme)
    }

    // MARK: 알림

    @ViewBuilder
    private var reminderGroup: some View {
        switch reminders.authorization {
        case .notDetermined:
            bellButton(symbol: "bell", label: "알림 켜기") {
                Task { await reminders.requestAuthorization() }
            }

        case .denied:
            bellButton(symbol: "bell.slash.fill", label: "iOS 설정에서 알림 켜기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }

        default:
            VStack(spacing: 0) {
                ForEach(reminders.reminders) { reminder in
                    reminderRow(reminder)
                    if reminder.slot != DailyColorLog.Slot.allCases.last {
                        Rectangle()
                            .fill(theme.stroke.opacity(0.7))
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 18)
            .settingsCard(theme)
        }
    }

    private func bellButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(theme.background)
                .frame(width: 58, height: 58)
                .background(theme.tint, in: .circle)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .settingsCard(theme)
        .accessibilityLabel(label)
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 14) {
            Image(systemName: reminder.slot.symbolName)
                .font(.system(size: 17))
                .foregroundStyle(reminder.isEnabled ? theme.tint : theme.inkSecondary.opacity(0.5))
                .frame(width: 26)
                .accessibilityLabel(reminder.slot.displayName)

            DatePicker(
                reminder.slot.displayName,
                selection: Binding(
                    get: { reminder.time },
                    set: { newTime in
                        var updated = reminder
                        updated.setTime(newTime)
                        reminders.update(updated)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .disabled(!reminder.isEnabled)
            .opacity(reminder.isEnabled ? 1 : 0.4)

            Spacer(minLength: 0)

            Toggle(
                reminder.slot.displayName,
                isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { isOn in
                        var updated = reminder
                        updated.isEnabled = isOn
                        reminders.update(updated)
                    }
                )
            )
            .labelsHidden()
            .tint(theme.tint)
        }
        .padding(.vertical, 14)
    }

}

private extension View {
    /// 설정의 묶음 하나를 감싸는 판.
    func settingsCard(_ theme: PaletteTheme) -> some View {
        background(
            theme.surface.opacity(theme.colorScheme == .dark ? 0.5 : 0.75),
            in: .rect(cornerRadius: 22, style: .continuous)
        )
    }
}

// MARK: - 팔레트 카드

/// 이름표가 없다. 그 팔레트로 칠해진 카드 자체가 이름이다.
/// 편집기 시트에 넘기는 팔레트 id.
private struct EditingPalette: Identifiable {
    let id: String
}

private struct PaletteCard: View {

    let palette: Palette
    let isSelected: Bool
    let action: () -> Void
    /// 있으면 마지막 칸이 '빈 날' 대신 붓 버튼이 된다(나만의 팔레트).
    var onEdit: (() -> Void)? = nil

    /// 자기 자신의 테마로 그려져야 한다. 현재 테마를 쓰면 모든 카드가
    /// 같은 배경 위에 놓여 '세계관의 차이'가 사라진다.
    private var ownTheme: PaletteTheme { palette.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ForEach(palette.swatches) { swatch in
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(swatch.color)
                        .frame(height: 46)
                }

                // 이 팔레트에서 '아직 오지 않은 날'이 어떻게 보이는지.
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(ownTheme.stroke.opacity(0.22))
                    .frame(height: 46)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(ownTheme.inkSecondary.opacity(0.3), lineWidth: 1)
                    }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(ownTheme.backgroundGradient, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        isSelected ? ownTheme.tint : ownTheme.stroke.opacity(0.6),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            }
            .shadow(color: .black.opacity(isSelected ? 0.16 : 0.05), radius: isSelected ? 14 : 5, y: 4)
            .scaleEffect(isSelected ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(palette.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        // 붓 버튼은 카드 버튼 밖에 겹쳐 둔다. 버튼 안의 버튼은 누르는 곳이 엉킨다.
        .overlay(alignment: .trailing) {
            if let onEdit {
                GeometryReader { proxy in
                    // 카드 안 여섯 칸(색 다섯 + 마지막 칸) 중 마지막 칸 자리.
                    let cell = (proxy.size.width - 32 - 10 * 5) / 6
                    Button(action: onEdit) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(ownTheme.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(ownTheme.inkSecondary.opacity(0.3), lineWidth: 1)
                            }
                            .overlay {
                                Image(systemName: "paintbrush.pointed.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(ownTheme.tint)
                            }
                            .frame(width: cell, height: 46)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    .scaleEffect(isSelected ? 1 : 0.98)
                    .accessibilityLabel("나만의 팔레트 색 바꾸기")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("설정") {
    @Previewable @State var selection = ColorPalette.default.rawValue
    @Previewable @State var syncsIcon = true

    SettingsView(selection: $selection, syncsAppIcon: $syncsIcon)
        .paletteTheme(Palette.resolve(selection))
        .environment(\.locale, .colorLog)
}
