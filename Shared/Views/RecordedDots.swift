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

    var body: some View {
        HStack(spacing: dotSize * 0.6) {
            ForEach(0..<DailyColorLog.maxColorsPerDay, id: \.self) { index in
                let hex = recordedHexes.indices.contains(index) ? recordedHexes[index] : ""
                Circle()
                    .fill(hex.isEmpty ? .clear : Color(hex: hex, fallback: emptyStroke))
                    .frame(width: dotSize, height: dotSize)
                    .overlay {
                        if hex.isEmpty {
                            Circle().strokeBorder(emptyStroke.opacity(0.55), lineWidth: 1)
                        }
                    }
            }
        }
    }
}
