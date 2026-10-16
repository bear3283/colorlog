//
//  SuccessPopupView.swift
//  colorlog
//
//  하루 세 자리를 다 채운 순간의 축하.
//
//  글자는 없다. 화면이 반투명하게 가라앉고, 오늘의 세 색으로 칠해진 곰이
//  아래에서 튀어 올라 만세를 부른다. 물감은 곰이 자리 잡는 동안 번진다.
//  잠깐 통통 뛰다가 스스로 내려가고, 화면 어디를 눌러도 바로 내려간다.
//
//  축하는 짧아야 한다. 오래 붙잡아 두면 칭찬이 아니라 광고가 된다.
//

import SwiftUI

struct SuccessPopupView: View {

    /// 오늘 채운 세 색.
    let colors: [Color]
    /// 오늘의 번짐 시드. 격자의 오늘 칸과 같은 번짐을 쓴다.
    let seed: UInt64
    let onDismiss: () -> Void

    /// 손대지 않으면 내려가기까지의 시간. 번짐(2초)이 끝나고 한 번 더 뛸 만큼.
    var lingering: Duration = .seconds(3.2)

    /// 무대에 올라와 있는지. false → true로 튀어 오르고, true → false로 내려간다.
    @State private var isShown = false
    @State private var isLeaving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width * 0.62, 320)

            ZStack {
                // 배경은 블러 한 장. 테두리도 그림자도 없이 격자를 뿌옇게 가라앉힌다.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(isShown ? 1 : 0)

                bear(side: side)
                    // 바닥 아래에서 튀어 올라 살짝 넘쳤다가 자리 잡는다.
                    .offset(y: isShown || reduceMotion ? 0 : proxy.size.height * 0.6)
                    .scaleEffect(isShown || reduceMotion ? 1 : 0.7)
                    .opacity(isShown ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: leave)
        .sensoryFeedback(.success, trigger: isShown) { _, shown in shown }
        .task {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.55, dampingFraction: 0.58)) {
                isShown = true
            }
            try? await Task.sleep(for: lingering)
            leave()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 세 가지 색을 모두 기록함")
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: "닫기", leave)
    }

    @ViewBuilder
    private func bear(side: CGFloat) -> some View {
        let painted = WatercolorBearView(moodColors: colors, pose: .cheering, seed: seed)
            .frame(width: side, height: side)

        if reduceMotion {
            painted
        } else {
            // 자리 잡은 뒤에는 제자리에서 통통 뛴다. 올라갈 땐 빠르게, 내려올 땐 튕기듯.
            painted.phaseAnimator([false, true]) { content, isUp in
                content.offset(y: isUp && isShown ? -side * 0.06 : 0)
            } animation: { isUp in
                isUp ? .easeOut(duration: 0.32) : .spring(response: 0.4, dampingFraction: 0.5)
            }
        }
    }

    private func leave() {
        guard !isLeaving else { return }
        isLeaving = true
        Task {
            withAnimation(.easeInOut(duration: 0.35)) { isShown = false }
            try? await Task.sleep(for: .milliseconds(350))
            onDismiss()
        }
    }
}

#Preview("달성 축하") {
    @Previewable @State var isPresented = true
    let palette = ColorPalette.default.swatches.map(\.color)

    ZStack {
        Color(red: 0.98, green: 0.97, blue: 0.95).ignoresSafeArea()
        Button("다시 축하", systemImage: "sparkles") { isPresented = true }

        if isPresented {
            SuccessPopupView(
                colors: [palette[0], palette[1], palette[3]],
                seed: Calendar.current.startOfDay(for: .now).colorSeed,
                onDismiss: { isPresented = false })
        }
    }
}
