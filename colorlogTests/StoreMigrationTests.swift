//
//  StoreMigrationTests.swift
//  colorlogTests
//
//  출시된 앱이 만든 저장소를 새 코드가 그대로 여는지.
//
//  픽스처(Fixtures/*.store)는 scripts/make_store_fixtures.sh가 출시 커밋의 모델 선언을
//  그대로 컴파일해 구운 것이다 — 새 코드의 SchemaV1/V2 정의로 만든 게 아니므로,
//  정의가 출시 모양과 어긋나면 이 테스트가 실패한다.
//  기록은 Asia/Seoul 자정(2025-10-01 · 02 · 03)으로 저장돼 있다.
//

import Foundation
import SQLite3
import SwiftData
import Testing
@testable import colorlog

@MainActor
@Suite(.serialized)
struct StoreMigrationTests {

    // MARK: 출시 저장소 열기

    @Test("1.0.1 저장소(V1)가 열리고 기록 세 개가 그대로다")
    func opensV1Store() throws {
        let url = try Fixture.copy("v1_0_1")
        let container = try ColorLogStore.openStore(at: url).get()
        let logs = try Self.fetchAll(container)

        #expect(logs.count == 3)
        #expect(logs.map(\.slotColors) == [
            ["#FF0000", "#00FF00", "#0000FF"],
            ["#112233", "", ""],
            ["", "#ABCDEF", ""],
        ])
        #expect(logs.allSatisfy { $0.themePalette == "pantone" })
        // V1에는 곰이 없었다. 날짜 시드 곰으로 그려진다.
        #expect(logs.allSatisfy { $0.poseRawValue == nil })
        #expect(logs.map { Self.seoulDay($0.date) } == [1, 2, 3])
    }

    @Test("1.1.0 저장소(V2)가 열리고 곰 동작까지 그대로다")
    func opensV2Store() throws {
        let url = try Fixture.copy("v1_1_0")
        let container = try ColorLogStore.openStore(at: url).get()
        let logs = try Self.fetchAll(container)

        #expect(logs.count == 3)
        #expect(logs[0].poseRawValue == "waving")
        #expect(logs[1].poseRawValue == nil)
        #expect(logs[2].poseRawValue == "sitting")
        #expect(logs[1].slotColors == ["#112233", "", ""])
    }

    @Test("실제 1.0.1 빌드(git 7f4b457)가 시뮬레이터에서 만든 저장소가 열린다")
    func opensStoreMadeByShippedBinary() throws {
        // 픽스처 생성기와 같은 모델 해시(Aot/RCds…)인지는 이 저장소가 증명한다 — 보고서 참고.
        let url = try Fixture.copy("shipped_1_0_1_empty")
        let container = try ColorLogStore.openStore(at: url).get()
        let context = ModelContext(container)
        context.insert(DailyColorLog(date: .now, colors: ["#FF0000"]))
        try context.save()
        #expect(try Self.fetchAll(container).count == 1)
    }

    @Test("V1 저장소를 올린 뒤 쓰고 다시 열어도 기록이 남는다", arguments: ["v1_0_1", "v1_1_0"])
    func migratedStoreIsWritableAndReopens(fixture: String) throws {
        let url = try Fixture.copy(fixture)
        do {
            let container = try ColorLogStore.openStore(at: url).get()
            let context = ModelContext(container)
            let logs = try context.fetch(FetchDescriptor<DailyColorLog>(sortBy: [SortDescriptor(\.date)]))
            #expect(logs[1].setColor("#445566", for: .evening))
            try context.save()
        }
        let reopened = try ColorLogStore.openStore(at: url).get()
        let logs = try Self.fetchAll(reopened)
        #expect(logs.count == 3)
        #expect(logs[1].slotColors == ["#112233", "", "#445566"])
    }

    // MARK: 열지 못할 때 — 파일을 지키는가

    @Test("앱이 모르는 버전의 저장소는 열지 않고, 파일도 건드리지 않는다")
    func unknownVersionFailsWithoutTouchingFile() throws {
        let url = try Fixture.copy("future")
        let before = try Data(contentsOf: url)

        let result = ColorLogStore.openStore(at: url)

        guard case .failure(let failure) = result else {
            Issue.record("모르는 스키마가 열려 버렸다 — 조용한 변환/손실 가능성")
            return
        }
        #expect(failure.kind == .openFailed)
        #expect(failure.storeURL == url)
        #expect(try Data(contentsOf: url) == before)
        // 모르는 스키마 위에 새 저장소를 만들지 않았다.
        let rows = try Fixture.rowCount(at: url)
        #expect(rows == 3)
    }

    @Test("손상된 파일은 열지 않고, 지우거나 덮어쓰지 않는다")
    func corruptFileFailsWithoutTouchingFile() throws {
        let folder = try Fixture.temporaryFolder()
        let url = folder.appending(path: "default.store")
        let garbage = Data((0..<8192).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
        try garbage.write(to: url)

        let result = ColorLogStore.openStore(at: url)

        guard case .failure(let failure) = result else {
            Issue.record("손상된 파일이 열려 버렸다")
            return
        }
        #expect(failure.kind == .openFailed)
        #expect(!failure.diagnosticCode.isEmpty)
        #expect(try Data(contentsOf: url) == garbage)
    }

    @Test("열지 못한 저장소의 복사본: 원본은 그대로, 같은 원본은 한 번만")
    func preserveCopyKeepsOriginal() throws {
        let url = try Fixture.copy("future")
        let before = try Data(contentsOf: url)

        let first = try #require(ColorLogStore.preserveCopy(of: url))
        let second = try #require(ColorLogStore.preserveCopy(of: url))

        #expect(first == second)
        #expect(try Data(contentsOf: first.appending(path: url.lastPathComponent)) == before)
        #expect(try Data(contentsOf: url) == before)
        let backups = try FileManager.default.contentsOfDirectory(atPath: first.deletingLastPathComponent().path)
        #expect(backups.count == 1)
    }

    @Test("새 저장소는 폴더가 없어도 만들어진다")
    func createsFreshStore() throws {
        let url = try Fixture.temporaryFolder()
            .appending(path: "Library/Application Support/default.store")
        let container = try ColorLogStore.openStore(at: url).get()
        #expect(try Self.fetchAll(container).isEmpty)
    }

    // MARK: 보조

    static let seoul: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private static func seoulDay(_ date: Date) -> Int {
        seoul.component(.day, from: date)
    }

    private static func fetchAll(_ container: ModelContainer) throws -> [DailyColorLog] {
        try ModelContext(container).fetch(FetchDescriptor<DailyColorLog>(sortBy: [SortDescriptor(\.date)]))
    }
}

// MARK: - 픽스처

enum Fixture {

    private final class Token {}

    /// 픽스처를 임시 폴더에 복사해 그 경로를 돌려준다. 원본 리소스는 건드리지 않는다.
    static func copy(_ name: String) throws -> URL {
        let bundle = Bundle(for: Token.self)
        let source = try #require(
            bundle.url(forResource: name, withExtension: "store")
                ?? bundle.url(forResource: name, withExtension: "store", subdirectory: "Fixtures"),
            "픽스처 \(name).store가 테스트 번들에 없다"
        )
        let destination = try temporaryFolder().appending(path: "default.store")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "colorlogTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// SwiftData를 거치지 않고 SQLite로 직접(읽기 전용) 센 행 수.
    static func rowCount(at url: URL) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM ZDAILYCOLORLOG", -1, &statement, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw CocoaError(.fileReadCorruptFile) }
        return Int(sqlite3_column_int64(statement, 0))
    }
}
