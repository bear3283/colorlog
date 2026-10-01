//
//  AppIconView.swift
//  colorlog
//
//  앱 아이콘을 따로 '디자인'하지 않는다. 제품이 스스로 그린다.
//
//  9칸 격자를 앱의 실제 셀(`DailyCellView`)로 채우므로, 아이콘은 이 앱이
//  만들어 내는 그림의 표본 그 자체가 된다. 팔레트를 바꾸면 아이콘도 따라 바뀐다.
//
//  구성 원칙
//   · 선이 아니라 '여백'으로 나뉜다. 칸 사이 간격으로 배경색이 비쳐 격자가 읽힌다.
//   · 3×3인 이유: 하루 3색 × MeshGradient 3×3 제어점, 그리고 정중앙 = 오늘.
//     (9×9는 29pt 아이콘에서 한 칸이 0.6pt라 격자가 뭉개진다)
//   · 따뜻함 → 차가움이 좌상단에서 우하단으로 흐르고, 중앙만 3색으로 가장 짙다.
//

import SwiftUI

struct AppIconView: View {

    let palette: ColorPalette

    /// 9칸에 들어갈 색 조합. 팔레트의 다섯 색(0~4) 인덱스로 적는다.
    /// 중앙(4번)만 3색이라 가장 진하고, 모서리로 갈수록 단색으로 옅어진다.
    private static let composition: [[Int]] = [
        [1],       [0, 1],      [0],
        [1, 2],    [0, 2, 3],   [0, 3],
        [2],       [2, 3],      [3, 4],
    ]

    /// 중앙에서 바깥으로 갈수록 살짝 물러난다. '오늘에서 번져나가는 기록'.
    private static let opacities: [Double] = [
        0.84, 0.94, 0.84,
        0.94, 1.00, 0.94,
        0.84, 0.94, 0.84,
    ]

    /// 셀의 번짐 무늬는 날짜 시드에서 나온다. 아이콘은 고정된 그림이어야 하므로
    /// 실제 날짜가 아니라 고정 기준일에서 칸마다 다른 오프셋을 준다.
    private static let seedAnchor = Date(timeIntervalSinceReferenceDate: 0)

    /// 아이콘 배경은 앱 배경보다 한 톤 깊다.
    /// 앱 안에서는 칸이 흰 여백 위에 놓여도 스크롤·테두리가 격자를 읽어 주지만,
    /// 29pt 아이콘에는 그런 단서가 없어서 명도 차만 남는다.
    private var backdrop: LinearGradient {
        LinearGradient(
            colors: [palette.theme.stroke, palette.theme.background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let inset = side * 0.135
            let gap = side * 0.042
            let cell = (side - inset * 2 - gap * 2) / 3

            ZStack {
                backdrop

                VStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<3, id: \.self) { column in
                                let index = row * 3 + column
                                DailyCellView(
                                    date: Self.seedAnchor.addingTimeInterval(
                                        Double(index) * 86_400
                                    ),
                                    colors: Self.composition[index].map { palette.swatches[$0].hex },
                                    relation: .past,
                                    cornerRadiusRatio: 0.22
                                )
                                .frame(width: cell, height: cell)
                                .opacity(Self.opacities[index])
                                // 여백만으로는 밝은 팔레트에서 격자가 읽히지 않는다.
                                // 칸을 배경에서 살짝 띄워 경계를 '선 없이' 만들어 낸다.
                                .shadow(
                                    color: .black.opacity(0.18),
                                    radius: cell * 0.07,
                                    y: cell * 0.025
                                )
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .environment(\.paletteTheme, palette.theme)
            .environment(\.colorPalette, palette)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("앱 아이콘") {
    VStack(spacing: 22) {
        ForEach(Array(ColorPalette.allCases.chunked(into: 2)), id: \.first) { row in
            HStack(spacing: 22) {
                ForEach(row) { palette in
                    VStack(spacing: 8) {
                        AppIconView(palette: palette)
                            .frame(width: 128, height: 128)
                            .clipShape(.rect(cornerRadius: 28, style: .continuous))

                        // 29pt에서도 격자가 읽히는지 확인하는 축소판.
                        AppIconView(palette: palette)
                            .frame(width: 29, height: 29)
                            .clipShape(.rect(cornerRadius: 6.5, style: .continuous))
                    }
                }
            }
        }
    }
    .padding(30)
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
