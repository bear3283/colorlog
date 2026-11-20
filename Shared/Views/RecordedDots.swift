//
//  RecordedDots.swift
//  colorlog (앱 · 위젯 공용)
//

import SwiftUI

/// ●○● — 아침·점심·저녁 자리가 각각 찼는지. 빈 자리는 빈 고리로 제자리에 남는다.
struct RecordedDots: View {

    /// 자리 순서의 HEX. ""는 빈 자리.
    let recordedHexes: [String]
    var dotSize: CGFloat = 7
    var emptyStroke: Color = .secondary
    /// 점이 놓인 바탕. 대비가 모자란 색에 먹선을 두를지 정한다. nil이면 앱 바탕.
    var backgroundHex: String? = nil

    var body: some View {
        HStack(spacing: dotSize * 0.6) {
            ForEach(0..<DailyColorLog.maxColorsPerDay, id: \.self) { index in
                let hex = recordedHexes.indices.contains(index) ? recordedHexes[index] : ""
                Circle()
                    .fill(hex.isEmpty ? .clear : Color(hex: hex, fallback: emptyStroke))
                    .frame(width: dotSize, height: dotSize)
                    .swatchOutline(hex: hex, on: backgroundHex)
                    .overlay {
                        if hex.isEmpty {
                            Circle().strokeBorder(emptyStroke.opacity(0.55), lineWidth: 1)
                        }
                    }
            }
        }
    }
}
