//
//  BearPosePicker.swift
//  colorlog
//
//  칠한 칸을 길게 누르면 올라오는 낮은 시트. 그날의 곰을 다른 동작으로 바꾼다.
//
//  곰의 동작은 처음 기록할 때 무작위로 정해진다. 색이 무슨 기분인지는 사용자만 알기에
//  앱은 동작을 강요하지 않고, 바꾸고 싶으면 여기서 고르게 한다.
//
//  글자는 없다. 그날의 색으로 칠한 곰 열네 마리가 한 줄로 늘어서 있고,
//  지금 동작인 곰 뒤에만 빛이 고인다. 하나를 누르면 시트 뒤 격자의 곰이 퐁 하고 바뀐다.
//  시트는 열어 둔 채로 몇 번이고 바꿔 볼 수 있고, 내려서 닫는다.
//
//  탭으로 동작을 순환시키지 않은 건 칸을 누르는 동작이 이미 '색 고르기'이기 때문이다.
//

import SwiftData
import SwiftUI
import WidgetKit

struct BearPosePicker: View {

    @Bindable var log: DailyColorLog

    @Environment(\.paletteTheme) private var theme
    @Environment(\.modelContext) private var modelContext

    private var currentPose: BearPose { log.pose ?? .random(for: log.date) }

    private var paints: [Color] {
        log.slotColors.filter { !$0.isEmpty }.map { Color(hex: $0, fallback: .gray) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(BearPose.allCases) { pose in
                        option(pose)
                            .id(pose)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 28)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .onAppear { proxy.scrollTo(currentPose, anchor: .center) }
        }
        .frame(maxHeight: .infinity)
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
        .sensoryFeedback(.selection, trigger: log.poseRawValue)
    }

    private func option(_ pose: BearPose) -> some View {
        let isCurrent = pose == currentPose

        return Button { choose(pose) } label: {
            WatercolorBearView(moodColors: paints, pose: pose, seed: log.date.colorSeed, bloomsOnAppear: false)
                .frame(width: 96, height: 96)
                .background {
                    // 격자의 오늘 칸과 같은 빛. '지금 이 곰'이라는 표시를 테두리 없이.
                    Circle()
                        .fill(theme.tint.opacity(theme.colorScheme == .dark ? 0.42 : 0.3))
                        .blur(radius: 10)
                        .opacity(isCurrent ? 1 : 0)
                }
                .scaleEffect(isCurrent ? 1.06 : 0.9)
                .animation(.spring(response: 0.38, dampingFraction: 0.6), value: isCurrent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pose.spokenName)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func choose(_ pose: BearPose) {
        guard pose != currentPose else { return }
        log.pose = pose
        do {
            try modelContext.save()
        } catch {
            assertionFailure("곰 동작 저장 실패: \(error)")
        }
        // 오늘의 곰은 위젯에도 앉아 있다.
        if Calendar.current.isDateInToday(log.date) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

#Preview("곰 바꾸기") {
    @Previewable @State var isPresented = true
    let container = ColorLogStore.inMemory()
    let palette = ColorPalette.default
    let log = DailyColorLog(date: .now, colors: [palette.swatches[0].hex, palette.swatches[3].hex], palette: palette)
    container.mainContext.insert(log)

    return VStack(spacing: 24) {
        DayBearCell(date: log.date, log: log, relation: .today, isHighlighted: true)
            .frame(width: 120, height: 120)
        Button("곰 바꾸기", systemImage: "hand.tap") { isPresented = true }
    }
    .sheet(isPresented: $isPresented) { BearPosePicker(log: log) }
    .modelContainer(container)
}
