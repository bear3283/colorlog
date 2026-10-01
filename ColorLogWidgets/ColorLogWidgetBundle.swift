//
//  ColorLogWidgetBundle.swift
//  ColorLogWidgets
//
//  Dynamic Island(라이브 액티비티)는 더 이상 올리지 않는다.
//  하루 종일 섬에 머무는 표시는 '물어보는 시각'이라는 리듬을 흐렸다.
//  묻는 일은 알림이, 고르는 일은 홈 화면의 위젯이 맡는다.
//

import SwiftUI
import WidgetKit

@main
struct ColorLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayColorWidget()
    }
}
