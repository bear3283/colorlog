//
//  AppIconView.swift
//  colorlog
//
//  앱 아이콘은 칼라베어의 곰 한 마리다.
//
//   · 기본 팔레트 — 원화 수채화 곰을 그대로 쓴다(`AppIconBear`, 앱 아이콘 icon-1024와 같은 그림).
//     물감 번짐과 종이 결이 코드로 칠한 것보다 깊어서, 가장 많이 보이는 기본 아이콘은 원화로 둔다.
//   · 다른 팔레트 — 같은 곰(`standing`)을 그 팔레트의 다섯 색으로 칠한다. 바탕은 그 팔레트의 바탕.
//     '팔레트를 바꾸면 아이콘도 따라 바뀐다'는 설정이 곰으로도 이어진다.
//
//  대체 아이콘 PNG는 이 뷰를 1024pt로 렌더해서 만든다.
//

import SwiftUI

struct AppIconView: View {

    let palette: Palette

    /// 아이콘의 번짐은 고정된 그림이어야 한다. 날짜가 아니라 상수 시드를 쓴다.
    private static let seed: UInt64 = 0xC0_10B3_A2

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            Group {
                if palette.alternateIconName == nil {
                    Image("AppIconBear")
                        .resizable()
                        .interpolation(.high)
                } else {
                    ZStack {
                        palette.theme.background
                        WatercolorBearView(
                            moodColors: palette.swatches.map(\.color),
                            pose: .standing,
                            seed: Self.seed,
                            bloomsOnAppear: false)
                            // 원화 아이콘과 같은 크기로 곰이 앉도록.
                            .padding(side * 0.06)
                            .environment(\.colorScheme, palette.theme.colorScheme)
                    }
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("앱 아이콘") {
    VStack(spacing: 22) {
        ForEach(Array(Palette.all.chunked(into: 2)), id: \.first?.id) { row in
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
