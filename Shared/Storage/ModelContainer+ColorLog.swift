//
//  ModelContainer+ColorLog.swift
//  colorlog
//
//  실제 컨테이너 + 프리뷰용 인메모리 컨테이너.
//  Step 2~4의 #Preview가 전부 여기에 기대므로 Step 1에 함께 둔다.
//

import Foundation
import OSLog
import SwiftData

nonisolated private let logger = Logger(subsystem: "com.colorlog", category: "store")

/// 위젯 익스텐션과 App Intent(백그라운드 프로세스)에서도 쓰이므로
/// 프로젝트 기본값인 MainActor 격리를 벗겨 둔다.
nonisolated enum ColorLogStore {

    /// 앱과 위젯이 같은 저장소를 보게 하는 App Group.
    /// 위젯은 별도 프로세스라 앱의 샌드박스 안을 들여다볼 수 없다.
    static let appGroupID = "group.com.eunkwanbear.colorlog"

    /// 앱과 위젯이 공유하는 설정 저장소.
    /// `UserDefaults.standard`는 프로세스별 샌드박스라 위젯이 앱의 값을 읽지 못한다.
    /// `UserDefaults`는 Sendable이 아니지만 스레드 안전이 보장된 타입이다.
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

    /// 선택된 팔레트 키. 앱과 위젯이 같은 문자열을 봐야 하므로 상수로 고정한다.
    static let paletteKey = "colorlog.palette"

    private static let firstUseKey = "colorlog.firstUse"

    /// 이 앱과 함께 시작한 날.
    ///
    /// 캔버스는 여기서부터 자란다. 처음 연 사람에게 지난 1년치 빈 격자를 펼쳐 보이면
    /// '채워야 할 숙제'처럼 읽힌다. 아무것도 없는 데서 시작해 하루씩 늘어나야
    /// 색을 채워 간다는 감각이 생긴다.
    static var firstUseDate: Date {
        let stored = defaults.double(forKey: firstUseKey)
        guard stored > 0 else { return Calendar.current.startOfDay(for: .now) }
        return Date(timeIntervalSinceReferenceDate: stored)
    }

    /// 앱이 처음 뜰 때 한 번 불러 시작일을 못 박는다.
    static func registerFirstUseIfNeeded() {
        guard defaults.double(forKey: firstUseKey) <= 0 else { return }
        let today = Calendar.current.startOfDay(for: .now)
        defaults.set(today.timeIntervalSinceReferenceDate, forKey: firstUseKey)
    }

    private static let celebratedKey = "colorlog.celebrated"

    /// 그날의 달성 축하를 차지한다. 이미 축하한 날이면 false.
    ///
    /// 하루에 한 번만 축하한다. 한 자리를 지웠다 다시 채울 때마다 팝업이 뜨면
    /// 축하가 아니라 방해가 된다. 위젯에서 세 번째 색을 고른 날은 앱을 열 때
    /// 여기서 처음 차지되므로, 그때 한 번 축하받는다.
    static func claimCelebration(for day: Date) -> Bool {
        let value = Calendar.current.startOfDay(for: day).timeIntervalSinceReferenceDate
        guard defaults.double(forKey: celebratedKey) != value else { return false }
        defaults.set(value, forKey: celebratedKey)
        return true
    }

    /// 앱과 위젯이 공유하는 영구 컨테이너.
    static let shared: ModelContainer = {
        let schema = Schema([DailyColorLog.self])
        do {
            return try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
                ]
            )
        } catch {
            // App Group이 아직 없는 환경(엔타이틀먼트 미설정 등)에서도 앱 자체는 떠야 한다.
            // 다만 이 경로로 떨어지면 위젯과 데이터가 갈라지므로 반드시 로그를 남긴다.
            logger.error("App Group 컨테이너 실패, 로컬 저장소로 대체: \(error.localizedDescription, privacy: .public)")
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("DailyColorLog 컨테이너 생성 실패: \(error)")
            }
        }
    }()

    /// 프리뷰/테스트용. 디스크에 남지 않는다.
    @MainActor
    static func inMemory(seedDays: Int = 0, palette: ColorPalette = .default) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: DailyColorLog.self, configurations: configuration)
            if seedDays > 0 {
                seed(into: container.mainContext, days: seedDays, palette: palette)
            }
            return container
        } catch {
            fatalError("프리뷰 컨테이너 생성 실패: \(error)")
        }
    }

    /// 과거 `days`일을 팔레트 색으로 채운다. 오늘은 일부러 1~2개만 채워 둬
    /// "아직 하루가 끝나지 않은" 상태를 프리뷰에서 볼 수 있게 한다.
    @MainActor
    static func seed(into context: ModelContext, days: Int, palette: ColorPalette) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var generator = SystemRandomNumberGenerator()

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            let count: Int = if offset == 0 {
                Int.random(in: 1...2, using: &generator)   // 오늘: 진행 중
            } else if offset % 11 == 0 {
                0                                          // 가끔은 기록을 놓친 날
            } else {
                Int.random(in: 1...3, using: &generator)
            }

            // 앞에서부터 채우되, 가끔은 가운데 자리를 비워 둔다(점심을 놓친 날).
            var hexes = (0..<count).map { _ in
                palette.swatches.randomElement(using: &generator)?.hex ?? ""
            }
            if count == 3, offset % 7 == 3 { hexes[1] = "" }
            context.insert(DailyColorLog(date: day, colors: hexes, palette: palette))
        }

        try? context.save()
    }
}

// MARK: - Fetch or Create

/// 알림·위젯·App Intent 어디서든 불린다.
nonisolated extension ModelContext {

    /// 그날의 로그를 가져오고, 없으면 만들어서 넣는다.
    /// 알림·위젯·앱 어디서 들어와도 같은 레코드를 잡도록 하는 단일 진입점.
    @discardableResult
    func dailyColorLog(for day: Date, palette: ColorPalette) throws -> DailyColorLog {
        var descriptor = FetchDescriptor<DailyColorLog>(
            predicate: DailyColorLog.predicate(for: day)
        )
        descriptor.fetchLimit = 1

        if let existing = try fetch(descriptor).first {
            return existing
        }
        let created = DailyColorLog(date: day, palette: palette)
        insert(created)
        return created
    }

    /// 그날의 한 자리에 색을 넣고(nil이면 비우고) 저장까지 끝낸다.
    /// 자리가 전부 비면 레코드를 지운다 — 빈 레코드가 '가장 오래된 기록'으로 잡혀
    /// 캔버스의 시작점을 끌어당기지 않도록.
    @discardableResult
    func setColor(
        _ hex: String?, for slot: DailyColorLog.Slot, on day: Date = .now, palette: ColorPalette
    ) throws -> Bool {
        let log = try dailyColorLog(for: day, palette: palette)
        guard log.setColor(hex, for: slot) else { return false }
        if log.isEmpty { delete(log) }
        try save()
        return true
    }
}
