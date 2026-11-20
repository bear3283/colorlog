//
//  ConcurrentWriteTests.swift
//  colorlogTests
//
//  앱과 위젯은 각자 컨테이너로 같은 파일에 쓴다. 한쪽이 쓴 자리를 다른 쪽이 덮지 않는지.
//  같은 파일에 컨테이너 두 개를 열어 두 프로세스를 흉내 낸다(코디네이터 · 캐시가 따로다).
//

import Foundation
import SwiftData
import Testing
@testable import colorlog

@MainActor
@Suite(.serialized)
struct ConcurrentWriteTests {

    static let seoul = DayKeyTests.seoul
    static let day = DayKeyTests.midnight(2026, 11, 20, in: DayKeyTests.seoul)

    private static func twoProcesses() throws -> (app: ModelContainer, widget: ModelContainer, url: URL) {
        let url = try Fixture.temporaryFolder().appending(path: "default.store")
        let app = try ColorLogStore.openStore(at: url).get()
        let widget = try ColorLogStore.openStore(at: url).get()
        return (app, widget, url)
    }

    private static func storedColors(at url: URL) throws -> [[String]] {
        let fresh = try ColorLogStore.openStore(at: url).get()
        return try ModelContext(fresh).fetch(FetchDescriptor<DailyColorLog>()).map(\.slotColors)
    }

    @Test("앱이 들고 있던 낡은 기록으로 저장해도 위젯이 넣은 자리가 남는다")
    func staleAppObjectDoesNotEraseWidgetSlot() throws {
        let (app, widget, url) = try Self.twoProcesses()
        let appContext = ModelContext(app)   // 화면의 mainContext처럼 객체를 계속 들고 있다

        try appContext.setColor("#FF0000", for: .morning, on: Self.day, palette: .default, calendar: Self.seoul)
        // 위젯 프로세스: 점심 자리
        try ModelContext(widget).setColor("#00FF00", for: .afternoon, on: Self.day, palette: .default, calendar: Self.seoul)
        // 다시 앱: 저녁 자리 — 앱의 객체는 아직 [빨강, "", ""]를 기억한다
        try appContext.setColor("#0000FF", for: .evening, on: Self.day, palette: .default, calendar: Self.seoul)

        #expect(try Self.storedColors(at: url) == [["#FF0000", "#00FF00", "#0000FF"]])
    }

    @Test("두 쪽이 같은 날들의 첫 기록을 동시에 만들어도 자리가 사라지지 않는다")
    func simultaneousFirstRecords() async throws {
        let url = try Fixture.temporaryFolder().appending(path: "default.store")
        _ = try ColorLogStore.openStore(at: url).get()   // 파일을 먼저 만들어 둔다
        let seoul = Self.seoul
        let days = (0..<15).map { DayKeyTests.midnight(2026, 10, 1 + $0, in: seoul) }

        func writer(_ slot: DailyColorLog.Slot, _ hex: String) -> Task<Void, any Error> {
            Task.detached {
                // 각자 자기 컨테이너 · 컨텍스트(다른 프로세스처럼)
                let container = try ColorLogStore.openStore(at: url).get()
                let context = ModelContext(container)
                for day in days {
                    try context.setColor(hex, for: slot, on: day, palette: .default, calendar: seoul)
                }
            }
        }
        let a = writer(.morning, "#AA0000")
        let b = writer(.afternoon, "#00BB00")
        try await a.value
        try await b.value

        let stored = try Self.storedColors(at: url)
        #expect(stored.count == days.count)
        #expect(stored.allSatisfy { $0 == ["#AA0000", "#00BB00", ""] })
    }

    @Test("잘못된 HEX는 빈 레코드를 남기지 않는다")
    func invalidHexLeavesNothing() throws {
        let container = ColorLogStore.inMemory()
        let context = container.mainContext
        #expect(try context.setColor("not-a-color", for: .morning, on: Self.day, palette: .default) == false)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<DailyColorLog>()).isEmpty)
    }

    @Test("쓰기 잠금: 잡혀 있으면 기다렸다가 쓴다")
    func lockSerializes() async throws {
        let url = try Fixture.temporaryFolder().appending(path: "default.store")
        let order = OrderLog()
        let holder = Task.detached {
            StoreWriteLock.withLock(for: url) {
                order.append("holder-start")
                Thread.sleep(forTimeInterval: 0.3)
                order.append("holder-end")
            }
        }
        try await Task.sleep(for: .milliseconds(100))
        await Task.detached {
            StoreWriteLock.withLock(for: url) { order.append("second") }
        }.value
        await holder.value
        #expect(order.items == ["holder-start", "holder-end", "second"])
    }
}

private final class OrderLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    func append(_ item: String) { lock.withLock { storage.append(item) } }
    var items: [String] { lock.withLock { storage } }
}
