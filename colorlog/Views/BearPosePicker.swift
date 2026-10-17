//
//  BearPosePicker.swift
//  colorlog
//
//  칠한 칸을 길게 누르면 올라오는 낮은 시트. 그날의 곰을 다른 동작으로 바꾼다.
//
//  곰의 동작은 처음 기록할 때 무작위로 정해진다. 색이 무슨 기분인지는 사용자만 알기에
//  앱은 동작을 강요하지 않고, 바꾸고 싶으면 여기서 고르게 한다.
//
//  줄 자체는 `BearPoseStrip`이다. 하루 한 장에서 큰 곰을 눌러도 같은 줄이 나온다.
//  하나를 누르면 시트 뒤 격자의 곰이 퐁 하고 바뀐다.
//  시트는 열어 둔 채로 몇 번이고 바꿔 볼 수 있고, 내려서 닫는다.
//
//  칸을 누르면 하루 한 장이 열리므로, 바로 바꾸는 지름길은 길게 누르기에 둔다.
//

import SwiftData
import SwiftUI

struct BearPosePicker: View {

    @Bindable var log: DailyColorLog

    @Environment(\.paletteTheme) private var theme

    var body: some View {
        BearPoseStrip(log: log)
            .frame(maxHeight: .infinity)
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.background)
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
