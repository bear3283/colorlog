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
import Synchronization

nonisolated private let logger = Logger(subsystem: "com.colorlog", category: "store")

/// 공유 저장소를 열지 못한 이유. 안내 화면과 로그가 쓴다.
nonisolated struct StoreOpenFailure: Error, Sendable {

    enum Kind: Sendable {
        /// App Group 엔타이틀먼트가 없어 공유 저장소에 닿을 수 없다.
        case appGroupUnavailable
        /// 저장소 파일을 열지 못했다. 파일은 그대로 남아 있다.
        case openFailed
    }

    let kind: Kind
    /// 열려던 파일. App Group이 없으면 nil.
    let storeURL: URL?
    let underlying: NSError?

    /// 문의를 받을 때 쓸 짧은 코드. 예: "NSCocoaErrorDomain 134504"
    var diagnosticCode: String {
        switch kind {
        case .appGroupUnavailable: "APPGROUP"
        case .openFailed: underlying.map { "\($0.domain) \($0.code)" } ?? "UNKNOWN"
        }
    }
}

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

    // MARK: 영구 저장소

    /// 앱과 위젯이 공유하는 영구 컨테이너. 열지 못했으면 nil.
    ///
    /// nil일 때 쓰기 쪽(위젯 인텐트)은 아무것도 쓰지 않고 실패를 알린다.
    /// 빈 저장소를 새로 만들어 대신 쓰지 않는다 — 그러면 사용자에게는 기록이 사라진 것처럼 보이고,
    /// 새 기록은 원래 저장소와 갈라진다.
    static var shared: ModelContainer? { try? sharedContainer().get() }

    /// 공유 컨테이너를 연다. 한 번 열리면 프로세스가 끝날 때까지 같은 것을 돌려준다.
    /// 실패는 캐시하지 않는다 — 앱의 '다시 시도'나 다음 위젯 갱신에서 다시 열어 본다
    /// (예: 첫 잠금 해제 전이라 파일 보호로 막혔던 경우).
    static func sharedContainer() -> Result<ModelContainer, StoreOpenFailure> {
        sharedCache.withLock { cached in
            if let cached { return .success(cached) }
            let result = openSharedStore()
            if case .success(let container) = result { cached = container }
            return result
        }
    }

    private static let sharedCache = Mutex<ModelContainer?>(nil)

    /// App Group 안의 저장소 파일. 1.0부터 같은 자리다
    /// (`ModelConfiguration(groupContainer:)`의 기본 위치 — 이름 "default").
    static func storeURL(inGroupContainer groupURL: URL) -> URL {
        groupURL.appending(path: "Library/Application Support/default.store", directoryHint: .notDirectory)
    }

    private static func openSharedStore() -> Result<ModelContainer, StoreOpenFailure> {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            // 원인 1: App Group 엔타이틀먼트가 없다(서명 없이 돌리는 개발 빌드 등).
            // 이 경우 열어야 할 공유 저장소 자체가 없으니 잃을 데이터도 없다.
            // 개발 빌드에서만 앱 샌드박스 저장소로 띄운다. 출시 빌드에서는 안내 화면으로 간다.
            #if DEBUG
            logger.error("App Group 없음(엔타이틀먼트 미설정) — 개발 빌드라 앱 샌드박스 저장소로 띄운다. 위젯과는 데이터가 갈라진다.")
            let localURL = URL.applicationSupportDirectory.appending(path: "default.store", directoryHint: .notDirectory)
            return openStore(at: localURL)
            #else
            logger.fault("App Group 없음(엔타이틀먼트 미설정) — 저장소를 열지 않는다.")
            return .failure(StoreOpenFailure(kind: .appGroupUnavailable, storeURL: nil, underlying: nil))
            #endif
        }
        // 원인 2: 저장소는 있는데 열지 못했다(모르는 스키마 버전 · 마이그레이션 실패 · 파일 손상 ·
        // 저장 공간 부족 · 파일 보호). 어느 쪽이든 파일은 건드리지 않고 실패로 돌려준다.
        return openStore(at: storeURL(inGroupContainer: groupURL))
    }

    /// 버전이 붙은 스키마와 마이그레이션 계획으로 저장소를 연다.
    ///
    /// 실패해도 파일을 지우거나 새로 만들지 않는다. 호출하는 쪽이 안내 화면을 띄운다.
    static func openStore(at url: URL) -> Result<ModelContainer, StoreOpenFailure> {
        do {
            // 첫 실행에서 폴더가 없으면 Core Data가 실패 → 복구를 한 번 거친다. 미리 만들어 둔다.
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let schema = Schema(versionedSchema: SchemaV2.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ColorLogMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: url)]
            )
            return .success(container)
        } catch {
            let failure = StoreOpenFailure(kind: .openFailed, storeURL: url, underlying: error as NSError)
            logger.fault("저장소 열기 실패 — 파일은 그대로 둔다: \(failure.diagnosticCode, privacy: .public) \(error.localizedDescription, privacy: .public)")
            return .failure(failure)
        }
    }

    /// 열지 못한 저장소 파일(본 파일 · -wal · -shm)을 옆 폴더에 복사해 둔다. 원본은 건드리지 않는다.
    ///
    /// 다음 버전이 고쳐서 열 수 있도록 원본을 지키는 게 먼저고, 복사본은 그 원본마저
    /// 잘못 다뤄질 때를 대비한 한 겹 더다. 같은 원본(크기 · 수정 시각)은 한 번만 복사한다.
    /// - Returns: 복사본 폴더. 원본이 없거나 이미 복사해 뒀으면 그 폴더, 실패하면 nil.
    @discardableResult
    static func preserveCopy(of storeURL: URL, fileManager: FileManager = .default) -> URL? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: storeURL.path) else { return nil }
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let folder = storeURL.deletingLastPathComponent()
            .appending(path: "Recovery", directoryHint: .isDirectory)
            .appending(path: "\(storeURL.lastPathComponent)-\(Int(modified))-\(size)", directoryHint: .isDirectory)
        if fileManager.fileExists(atPath: folder.path) { return folder }
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let source = URL(filePath: storeURL.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                try fileManager.copyItem(at: source, to: folder.appending(path: source.lastPathComponent))
            }
            logger.notice("열지 못한 저장소를 복사해 뒀다: \(folder.lastPathComponent, privacy: .public)")
            return folder
        } catch {
            logger.error("저장소 복사본 만들기 실패: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 프리뷰/테스트용. 디스크에 남지 않는다.
    @MainActor
    static func inMemory(seedDays: Int = 0, palette: Palette = .default) -> ModelContainer {
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
    static func seed(into context: ModelContext, days: Int, palette: Palette) {
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
    func dailyColorLog(for day: Date, palette: Palette) throws -> DailyColorLog {
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
        _ hex: String?, for slot: DailyColorLog.Slot, on day: Date = .now, palette: Palette
    ) throws -> Bool {
        let log = try dailyColorLog(for: day, palette: palette)
        guard log.setColor(hex, for: slot) else { return false }
        if log.isEmpty { delete(log) }
        try save()
        return true
    }
}
