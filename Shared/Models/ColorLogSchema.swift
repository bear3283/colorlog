//
//  ColorLogSchema.swift
//  colorlog (앱 · 위젯 공용)
//
//  출시된 저장소 모양의 이력.
//
//  SwiftData는 저장소에 적힌 모델 해시로 "이 파일이 어느 버전인지"를 알아본다.
//  그래서 각 버전의 @Model 선언은 **출시된 모양과 글자 하나까지 같아야** 한다
//  (속성 이름 · 타입 · 선택 여부 · #Unique · #Index). 한 번 출시된 버전은 절대 고치지 않는다.
//
//    V1  1.0 · 1.0.1   date · colors · themePalette          (커밋 7f4b457)
//    V2  1.1.0         + poseRawValue: String?                (커밋 cf69a4b → 2485d47)
//
//  1.0.x · 1.1.0 앱은 버전 없는 `Schema([DailyColorLog.self])`로 저장소를 만들었다.
//  그 파일도 해시가 V1 또는 V2와 같으므로 이 계획으로 그대로 열린다
//  (colorlogTests/StoreMigrationTests — 출시 커밋의 모델 선언으로 구운 저장소로 확인).
//
//  다음 스키마 변경 순서:
//    1) `SchemaV3`를 새로 만들고 `DailyColorLog` typealias를 V3로 옮긴다.
//    2) `ColorLogMigrationPlan.schemas`/`stages`에 V3와 단계를 더한다.
//    3) scripts/make_store_fixtures.sh에 이번 출시 커밋을 더해 픽스처를 굽고 테스트를 더한다.
//

import Foundation
import SwiftData

// MARK: - V1 (1.0 · 1.0.1)

enum SchemaV1: VersionedSchema {

    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [DailyColorLog.self] }

    /// 1.0.1 출시 모양 그대로. 앱 코드는 이 타입을 쓰지 않는다 — 옛 저장소를 알아보는 데만 쓴다.
    @Model
    final class DailyColorLog {

        #Unique<DailyColorLog>([\.date])
        #Index<DailyColorLog>([\.date])

        private(set) var date: Date
        private(set) var colors: [String]
        var themePalette: String

        init(date: Date, colors: [String], themePalette: String) {
            self.date = date
            self.colors = colors
            self.themePalette = themePalette
        }
    }
}

// MARK: - V2 (1.1.0 · 현재)

/// 모델 본문은 DailyColorLog.swift에 있다(`extension SchemaV2`).
enum SchemaV2: VersionedSchema {

    static var versionIdentifier: Schema.Version { Schema.Version(1, 1, 0) }
    static var models: [any PersistentModel.Type] { [DailyColorLog.self] }
}

// MARK: - 마이그레이션 계획

enum ColorLogMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }

    /// V1 → V2: 선택 속성(`poseRawValue`) 하나가 늘었을 뿐이라 경량 마이그레이션.
    /// 옛 기록의 곰은 nil — 화면은 날짜 시드 곰을 그대로 보여 준다.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
