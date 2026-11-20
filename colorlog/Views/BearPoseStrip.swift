//
//  BearPoseStrip.swift
//  colorlog
//
//  그날의 색으로 칠한 곰 서른다섯 마리가 늘어선 가로 줄. 하나를 누르면 그날의 곰이 된다.
//
//  두 곳에서 쓴다.
//   · 하루 한 장(`DayDetailSheet`) — 큰 곰을 누르면 색 줄 자리에 이 줄이 올라온다.
//   · 격자 칸을 길게 눌렀을 때의 낮은 시트(`BearPosePicker`) — 바로 바꾸는 지름길.
//
//  글자는 없다. 지금 동작인 곰 뒤에만 빛이 고인다.
//

import OSLog
import SwiftData
import SwiftUI
import WidgetKit

private let logger = Logger(subsystem: "com.colorlog", category: "store")

struct BearPoseStrip: View {

    @Bindable var log: DailyColorLog
    /// 곰 한 마리의 크기.
    var bearSize: CGFloat = 96
    /// 곰을 고른 뒤. 같은 곰을 다시 눌러도 불린다 — '이 곰으로 할게'라는 뜻이다.
    var onChoose: (BearPose) -> Void = { _ in }

    @Environment(\.paletteTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    /// 저장하지 못했을 때 알린다. 조용히 넘어가면 다음에 열었을 때 곰이 돌아가 있다.
    @State private var isShowingSaveError = false

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
        .alert("곰을 바꾸지 못했어요", isPresented: $isShowingSaveError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("저장 중 문제가 생겼어요. 잠시 뒤 다시 시도해 주세요.")
        }
        .sensoryFeedback(.selection, trigger: log.poseRawValue)
    }

    private func option(_ pose: BearPose) -> some View {
        let isCurrent = pose == currentPose

        return Button { choose(pose) } label: {
            WatercolorBearView(moodColors: paints, pose: pose, seed: log.date.colorSeed, bloomsOnAppear: false)
                .frame(width: bearSize, height: bearSize)
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
        guard pose != currentPose else {
            onChoose(pose)
            return
        }
        log.pose = pose
        do {
            try modelContext.save()
        } catch {
            // 저장 못 한 변경을 남겨 두지 않는다 — 화면이 저장된 것처럼 보이지 않게.
            modelContext.rollback()
            logger.error("곰 동작 저장 실패: \(error.localizedDescription, privacy: .public)")
            isShowingSaveError = true
            return
        }
        defer { onChoose(pose) }
        // 오늘의 곰은 위젯에도 앉아 있다.
        if log.day() == DayKey(.now) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
