//
//  WatercolorLayoutTests.swift
//  colorlogTests
//
//  색을 하나 더해도 이미 칠해진 얼룩은 자리 · 모양 · 색이 그대로인지.
//  그래야 '새 색만 번지기'가 성립한다.
//

import CoreGraphics
import Foundation
import Testing
@testable import colorlog

@MainActor
struct WatercolorLayoutTests {

    private static let seeds: [UInt64] = [0, 1, 42, 0xC0_10B3_A2, 0xDEAD_BEEF, 20_261_121]
    private static let poses: [BearPose] = [.standing, .sitting, .reading, .umbrella, .peeking]

    @Test("1 → 2 → 3색: 얼룩 자리와 모양은 같고, 색은 새 색이 차지한 얼룩만 바뀐다", arguments: seeds)
    func addingColorKeepsExistingWashes(seed: UInt64) {
        for pose in Self.poses {
            let layouts = (1...3).map { WatercolorWash.layout(count: $0, seed: seed, occupancy: pose.occupancy) }
            for (before, after) in zip(layouts, layouts.dropFirst()) {
                #expect(before.count == after.count)
                #expect(!before.isEmpty)
                for (old, new) in zip(before, after) {
                    #expect(old.center == new.center)
                    #expect(old.radius == new.radius)
                    #expect(old.contour == new.contour)
                    #expect(old.innerOffset == new.innerOffset)
                    // 바뀐다면 새로 온 색(마지막 색)으로만.
                    if old.colorIndex != new.colorIndex {
                        #expect(new.colorIndex == after.map { $0.colorIndex }.max())
                    }
                }
            }
        }
    }

    @Test("한 색이면 모든 얼룩이 그 색, 세 색이면 세 색이 다 쓰인다", arguments: seeds)
    func everyColorIsUsed(seed: UInt64) {
        for pose in Self.poses {
            #expect(Set(WatercolorWash.layout(count: 1, seed: seed, occupancy: pose.occupancy).map(\.colorIndex)) == [0])
            #expect(Set(WatercolorWash.layout(count: 3, seed: seed, occupancy: pose.occupancy).map(\.colorIndex)) == [0, 1, 2])
        }
    }

    @Test("색이 없으면 얼룩도 없다")
    func noColors() {
        #expect(WatercolorWash.layout(count: 0, seed: 1, occupancy: BearPose.standing.occupancy).isEmpty)
    }
}
