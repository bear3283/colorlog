//
//  TimelineGridView.swift
//  colorlog
//
//  '지금'을 원점으로 위아래로 펼쳐지는 색의 캔버스.
//
//  달력이 아니다. 그래서 월 표시도, 요일 머리글도 없다. 화면에 글자를 한 자라도
//  올리는 순간 캔버스가 '표'로 읽히기 시작한다.
//
//  시간은 글을 읽듯 왼쪽에서 오른쪽으로, 위에서 아래로 흐른다.
//  위가 과거, 아래가 미래(3행까지). 오늘은 가로·세로 정중앙.
//
//  캔버스는 **앱과 함께 시작한 날부터** 존재한다. 그 이전 칸은 그리지 않는다.
//  처음 연 사람에게 지난 1년치 빈 격자를 펼쳐 보이면 '숙제'처럼 읽히기 때문에,
//  아무것도 없는 데서 시작해 하루씩 자라게 둔다.
//
//  데이터 전략 메모:
//  전체 로그를 한 번에 @Query로 받아 [Date: Log] 딕셔너리를 만드는 방식은 쓰지 않는다.
//  스크롤 상태가 바뀔 때마다 부모 body가 재평가되면서 수천 건짜리 딕셔너리를
//  다시 만들게 되기 때문이다. 대신 행마다 자기 7일치만 @Query 한다.
//

import SwiftUI
import SwiftData
import WidgetKit

struct TimelineGridView: View {

    /// 원형 팔레트가 칸의 위치를 읽어 오는 좌표 공간.
    private static let canvasSpace = "colorlog.canvas"

    var horizontalPadding: CGFloat = 18
    var spacing: CGFloat = 7
    var onOpenSettings: () -> Void = {}
    /// 알림을 눌러 들어온 경우 열어야 할 날. 처리한 뒤 nil로 되돌린다.
    var openRequest: Binding<Date?> = .constant(nil)

    @Environment(\.paletteTheme) private var theme
    @Environment(\.colorPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(oldestLogDescriptor) private var oldestLogs: [DailyColorLog]

    /// 자정을 넘겨도 원점이 어제에 머물지 않도록 상태로 들고 간다.
    @State private var today = Calendar.current.startOfDay(for: .now)
    /// 오늘 행이 화면에 보이는지. 스크롤 좌표를 역산하는 대신 시스템이 알려 주는
    /// 가시성을 그대로 쓴다 — 여백·안전영역 계산이 한 군데라도 어긋나면
    /// 버튼이 엉뚱할 때 떠 버리기 때문.
    @State private var isTodayVisible = true
    @State private var selectedDate: Date?
    @State private var selectedFrame: CGRect?
    /// 칸들의 화면 위치. 스크롤할 때마다 바뀌므로 @State에 두면 그때마다 body가 다시 돈다.
    /// 관찰되지 않는 상자에 담아 두고 탭하는 순간에 꺼내 쓴다.
    @State private var frames = CellFrameBox()
    /// 지금 축하하고 있는 오늘의 세 색. nil이면 축하 중이 아니다.
    @State private var celebration: [String]?

    private var mapper: TimelineMapper { TimelineMapper(today: today) }

    /// 캔버스가 시작하는 날. 앱과 함께한 첫날, 또는 그보다 오래된 기록이 있으면 그날.
    private var startDate: Date {
        let first = ColorLogStore.firstUseDate
        guard let oldest = oldestLogs.first?.date else { return first }
        return min(first, oldest)
    }

    /// 가장 위(가장 과거) 행. 오늘보다 뒤일 수는 없다.
    private var firstRow: Int {
        min(0, mapper.row(containing: startDate) ?? 0)
    }

    /// 가장 아래(가장 미래) 행. 격자가 화면 아래 끝까지 이어진다.
    private func lastRow(cellSide: CGFloat, viewportHeight: CGFloat) -> Int {
        TimelineMapper.lastRow(
            viewportHeight: viewportHeight, cellSide: cellSide, spacing: spacing
        )
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            GeometryReader { proxy in
                let side = cellSide(containerWidth: proxy.size.width)
                let insets = proxy.safeAreaInsets
                // 격자는 상태바·홈 인디케이터 아래까지 깔린다. 그래야 '오늘 = 화면 정중앙'이
                // 안전영역의 중앙이 아니라 **기기 화면의 중앙**이 된다.
                // 안전영역 안에서 중앙을 잡으면 위쪽 상태바만큼 아래로 내려앉아 보인다.
                let fullHeight = proxy.size.height + insets.top + insets.bottom

                ZStack {
                    canvas(cellSide: side, viewportHeight: fullHeight, proxy: scrollProxy)

                    if let selectedDate, let selectedFrame {
                        let slots = colors(on: selectedDate)
                        RadialColorPicker(
                            palette: palette,
                            slotColors: slots,
                            initialSlot: DailyColorLog.Slot.defaultSelection(
                                slotColors: slots, due: dueSlots(on: selectedDate)
                            ),
                            anchor: selectedFrame,
                            bounds: proxy.size,
                            onSet: { slot, hex in setColor(hex, for: slot, on: selectedDate) },
                            onDismiss: { close() }
                        )
                        .id(selectedDate)
                    }
                }
                .coordinateSpace(.named(Self.canvasSpace))
                // 버튼들은 격자와 달리 안전영역 안에 머문다.
                .overlay(alignment: .top) { topBar }
                .overlay(alignment: .bottom) {
                    returnToTodayButton(proxy: scrollProxy)
                        .animation(.smooth(duration: 0.3), value: isTodayVisible)
                }
            }
        }
        .background(SunlightBackground(theme: theme))
        // 축하는 상단 버튼까지 덮는다. 떠 있는 동안에는 격자를 만질 일이 없다.
        .overlay {
            if let celebration {
                SuccessPopupView(
                    colors: celebration.map { Color(hex: $0, fallback: .gray) },
                    seed: today.colorSeed,
                    onDismiss: { self.celebration = nil })
            }
        }
        // 위젯에서 세 번째 색을 고른 날은 앱으로 돌아오는 순간 축하한다.
        .onAppear(perform: celebrateIfComplete)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { celebrateIfComplete() }
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification
        )) { _ in
            let current = Calendar.current.startOfDay(for: .now)
            if current != today {
                withAnimation(.smooth) { today = current }
            }
        }
    }

    private func cellSide(containerWidth: CGFloat) -> CGFloat {
        let columns = CGFloat(TimelineMapper.columnCount)
        let available = containerWidth - horizontalPadding * 2 - spacing * (columns - 1)
        return max(24, available / columns)
    }

    // MARK: 캔버스

    /// 오늘을 화면 한가운데에 놓기 위해 한쪽에 더 있어야 하는 여백.
    /// `rows`는 오늘 기준 그쪽에 실제로 존재하는 행 수.
    private func centeringInset(rows: Int, cellSide: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let rowStride = cellSide + spacing
        return max(0, viewportHeight / 2 - cellSide / 2 - CGFloat(rows) * rowStride)
    }

    private func canvas(
        cellSide: CGFloat, viewportHeight: CGFloat, proxy: ScrollViewProxy
    ) -> some View {
        ScrollView(.vertical) {
                LazyVStack(spacing: spacing) {
                    ForEach(firstRow...lastRow(cellSide: cellSide, viewportHeight: viewportHeight), id: \.self) { row in
                        TimelineRowView(
                            row: row,
                            mapper: mapper,
                            cellSide: cellSide,
                            spacing: spacing,
                            startDate: startDate,
                            selectedDate: selectedDate,
                            selectedFrame: $selectedFrame,
                            frames: frames,
                            coordinateSpace: Self.canvasSpace,
                            onTap: { date in open(date) }
                        )
                        .id(row)
                        .modifier(TodayVisibilityReporter(isTodayRow: row == 0, isVisible: $isTodayVisible))
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, horizontalPadding)
                // 캔버스가 아직 짧아도 오늘은 화면 정중앙에 온다.
                // 기록이 쌓여 행이 늘어나면 이 여백은 저절로 0이 된다.
                .padding(.top, centeringInset(rows: -firstRow, cellSide: cellSide, viewportHeight: viewportHeight))
                .padding(.bottom, centeringInset(
                    rows: lastRow(cellSide: cellSide, viewportHeight: viewportHeight),
                    cellSide: cellSide, viewportHeight: viewportHeight
                ))
            }
        // 격자는 안전영역을 넘어 화면 끝까지.
        .ignoresSafeArea(.container, edges: .vertical)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        .scrollIndicators(.hidden)
        .scrollDisabled(selectedDate != nil)
        // 스크롤이 움직이면 닫던 로직은 뺐다.
        // 감속이 남은 동안 탭하면 열리자마자 닫혀 '눌러도 반응이 없는' 것처럼 보였다.
        // 앵커는 선택된 칸이 계속 보고하므로, 격자가 움직여도 원이 그대로 따라간다.
        // 오늘을 화면 한가운데로. 스크롤 뷰가 화면 전체를 차지하므로
        // .center가 곧 기기 화면의 중앙이다.
        .task {
            proxy.scrollTo(0, anchor: .center)
            consumeOpenRequest(proxy: proxy)
        }
        .onChange(of: openRequest.wrappedValue) { _, _ in
            consumeOpenRequest(proxy: proxy)
        }
    }

    // MARK: 얹히는 것들

    /// 화면 위에 얹히는 유일한 것. 왼쪽은 오늘 채운 색, 오른쪽은 팔레트 진입점.
    ///
    /// 격자가 배경까지 꽉 차 있어서 그냥 얹으면 읽히지 않는다.
    /// 반투명 판을 깔아 아래 격자가 비치되 내용은 뜨도록 한다.
    private var topBar: some View {
        HStack(spacing: 12) {
            TodayProgressView(date: today)
            Spacer(minLength: 0)
            paletteButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(theme.surface.opacity(0.72), in: .capsule)
        .overlay { Capsule().strokeBorder(theme.stroke.opacity(0.5), lineWidth: 0.6) }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 6)
        .opacity(selectedDate == nil ? 1 : 0)
        .animation(.smooth(duration: 0.2), value: selectedDate)
    }

    /// 설정 진입점. 아이콘도 글자도 아닌, 지금 팔레트의 색 자체.
    private var paletteButton: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: 4) {
                ForEach(palette.swatches) { swatch in
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("팔레트 바꾸기")
    }

    /// 오늘에서 멀어지면 돌아올 길을 남긴다. 글자 대신 틴트 색 점 하나.
    @ViewBuilder
    private func returnToTodayButton(proxy: ScrollViewProxy) -> some View {
        if !isTodayVisible, selectedDate == nil {
            Button {
                withAnimation(.smooth(duration: 0.45)) {
                    proxy.scrollTo(0, anchor: .center)
                }
            } label: {
                Circle()
                    .fill(theme.tint)
                    .frame(width: 12, height: 12)
                    .padding(14)
                    .background(theme.surface.opacity(0.85), in: .circle)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .accessibilityLabel("오늘로 돌아가기")
        }
    }

    // MARK: 동작

    /// 칸을 누르면 날짜만 세운다.
    ///
    /// 위치는 계산하지 않는다. 예전에는 (행, 열)과 스크롤 오프셋으로 화면 좌표를
    /// 산술로 구했는데, 안전영역·콘텐츠 인셋·스냅 애니메이션 중 하나만 어긋나도
    /// 원이 뒤 격자와 맞지 않았다. 지금은 **선택된 칸이 자기 프레임을 직접 보고**한다.
    private func open(_ date: Date) {
        if selectedDate == date {
            close()
            return
        }
        // 위치를 '나중에 알려 주기를 기다리지' 않는다. 이미 받아 둔 값을 그 자리에서 쓴다.
        // 기다리는 구조였을 때는 알림이 오지 않으면 팔레트가 영영 뜨지 않고,
        // scrollDisabled까지 걸려 화면이 죽은 것처럼 보였다.
        guard let frame = frames.rects[date] else { return }
        withAnimation(.smooth(duration: 0.28)) {
            selectedDate = date
            selectedFrame = frame
        }
    }

    private func close() {
        withAnimation(.smooth(duration: 0.24)) {
            selectedDate = nil
            selectedFrame = nil
        }
    }

    /// 자리 순서의 HEX. 언제나 세 칸, 빈 자리는 "".
    private func colors(on date: Date) -> [String] {
        var descriptor = FetchDescriptor<DailyColorLog>(predicate: DailyColorLog.predicate(for: date))
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first?.slotColors)
            ?? Array(repeating: "", count: DailyColorLog.maxColorsPerDay)
    }

    /// 그날 이미 물어본 자리들. 지난날은 셋 다 지나갔다.
    private func dueSlots(on date: Date) -> [DailyColorLog.Slot] {
        guard Calendar.current.isDate(date, inSameDayAs: today) else {
            return DailyColorLog.Slot.allCases
        }
        return Reminder.dueSlots(at: .now, reminders: ReminderStore.shared.reminders)
    }

    /// 한 자리에 색을 넣거나 비운다. 다른 자리는 그대로 있다.
    private func setColor(_ hex: String?, for slot: DailyColorLog.Slot, on date: Date) {
        withAnimation(.smooth(duration: 0.3)) {
            do {
                try modelContext.setColor(hex, for: slot, on: date, palette: palette)
            } catch {
                assertionFailure("색 기록 실패: \(error)")
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        // 고른 색이 칸을 채우는 순간을 잠깐 보여 준 뒤 닫는다.
        // 이 지연 동안에도 원형 팔레트는 이미 탭을 받지 않으므로 다음 탭이 막히지 않는다.
        withAnimation(.smooth(duration: 0.26).delay(0.16)) {
            selectedDate = nil
            selectedFrame = nil
        }
        // 세 번째 색이 칸을 채우고 팔레트가 닫힌 걸 본 다음에 축하한다.
        if Calendar.current.isDate(date, inSameDayAs: today) {
            Task {
                try? await Task.sleep(for: .milliseconds(480))
                celebrateIfComplete()
            }
        }
    }

    /// 오늘 세 자리가 다 찼고 아직 축하하지 않았으면 축하한다.
    private func celebrateIfComplete() {
        guard celebration == nil else { return }
        let slots = colors(on: today)
        guard BearState(filledCount: slots.count { !$0.isEmpty }) == .completed,
              ColorLogStore.claimCelebration(for: today) else { return }
        celebration = slots
    }

    /// 알림에서 넘어온 날을 화면 한가운데로 가져온다.
    private func consumeOpenRequest(proxy: ScrollViewProxy) {
        guard let requested = openRequest.wrappedValue else { return }
        openRequest.wrappedValue = nil
        guard let position = mapper.position(of: requested) else { return }

        withAnimation(.smooth(duration: 0.4)) {
            proxy.scrollTo(position.row, anchor: .center)
        }
    }
}

// MARK: - 오늘 행 가시성

/// 오늘 행에만 가시성 관찰을 붙인다. 모든 행에 붙이면 스크롤할 때마다
/// 수십 번씩 불리는 콜백이 생긴다.
private struct TodayVisibilityReporter: ViewModifier {
    let isTodayRow: Bool
    @Binding var isVisible: Bool

    func body(content: Content) -> some View {
        if isTodayRow {
            content.onScrollVisibilityChange(threshold: 0.6) { isVisible = $0 }
        } else {
            content
        }
    }
}

// MARK: - 오늘 채운 색

/// 아침·점심·저녁 자리 세 개. 고른 색이 그대로 칠해진다.
private struct TodayProgressView: View {

    let date: Date

    @Environment(\.paletteTheme) private var theme
    @Query private var logs: [DailyColorLog]

    init(date: Date) {
        self.date = date
        var descriptor = FetchDescriptor<DailyColorLog>(
            predicate: DailyColorLog.predicate(for: date)
        )
        descriptor.fetchLimit = 1
        _logs = Query(descriptor)
    }

    var body: some View {
        RecordedDots(
            recordedHexes: logs.first?.slotColors ?? [],
            dotSize: 11,
            emptyStroke: theme.inkSecondary
        )
        .animation(.smooth(duration: 0.3), value: logs.first?.slotColors ?? [])
        .accessibilityElement()
        .accessibilityLabel("오늘 \(logs.first?.filledCount ?? 0)개 기록됨")
    }
}

// MARK: - 한 행 (7일)

private struct TimelineRowView: View {

    let row: Int
    let mapper: TimelineMapper
    let cellSide: CGFloat
    let spacing: CGFloat
    /// 캔버스가 시작하는 날. 이보다 이른 칸은 아예 그리지 않는다.
    let startDate: Date
    let selectedDate: Date?
    @Binding var selectedFrame: CGRect?
    let frames: CellFrameBox
    let coordinateSpace: String
    let onTap: (Date) -> Void

    /// 이 행이 덮는 7일치만 조회한다.
    @Query private var logs: [DailyColorLog]

    init(
        row: Int,
        mapper: TimelineMapper,
        cellSide: CGFloat,
        spacing: CGFloat,
        startDate: Date,
        selectedDate: Date?,
        selectedFrame: Binding<CGRect?>,
        frames: CellFrameBox,
        coordinateSpace: String,
        onTap: @escaping (Date) -> Void
    ) {
        self.row = row
        self.mapper = mapper
        self.cellSide = cellSide
        self.spacing = spacing
        self.startDate = startDate
        self.selectedDate = selectedDate
        self._selectedFrame = selectedFrame
        self.frames = frames
        self.coordinateSpace = coordinateSpace
        self.onTap = onTap

        let range = mapper.dayRange(row: row)
        _logs = Query(
            filter: DailyColorLog.predicate(from: range.start, until: range.end),
            sort: [SortDescriptor(\DailyColorLog.date)]
        )
    }

    private var logsByDate: [Date: DailyColorLog] {
        Dictionary(logs.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        let lookup = logsByDate

        HStack(spacing: spacing) {
            ForEach(0..<TimelineMapper.columnCount, id: \.self) { column in
                let date = mapper.date(row: row, column: column)
                let relation = mapper.relation(row: row, column: column)

                if date < startDate {
                    // 앱을 쓰기 전의 날. 칸이 없는 게 맞다 — 자리만 비워 둔다.
                    Color.clear
                        .frame(width: cellSide, height: cellSide)
                } else {
                    DailyCellView(
                        date: date,
                        log: lookup[date],
                        relation: relation,
                        isHighlighted: relation == .today
                    )
                    .frame(width: cellSide, height: cellSide)
                    // 조건 없이 모든 칸이 자기 자리를 보고한다. 조건부로 붙이면
                    // 탭하는 순간 뷰 아이덴티티가 바뀌어 제스처가 취소될 수 있고,
                    // 새로 붙은 수식어가 알림을 한 번도 안 줄 수도 있다.
                    .onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .named(coordinateSpace))
                    } action: { rect in
                        frames.rects[date] = rect
                        // 열려 있는 칸이면 원형 팔레트도 같이 따라간다.
                        if selectedDate == date { selectedFrame = rect }
                    }
                    .contentShape(.rect)
                    .onTapGesture { onTap(date) }
                    .allowsHitTesting(relation != .future)
                }
            }
        }
    }
}

/// 칸들의 화면 위치를 담아 두는 상자.
///
/// 관찰되지 않는 평범한 클래스다. 여기에 값을 써도 뷰가 다시 그려지지 않으므로,
/// 스크롤하는 동안 매 프레임 갱신해도 비용이 거의 없다.
private final class CellFrameBox {
    var rects: [Date: CGRect] = [:]
}

// MARK: - 가장 오래된 기록 (캔버스의 끝을 정한다)

private let oldestLogDescriptor: FetchDescriptor<DailyColorLog> = {
    var descriptor = FetchDescriptor<DailyColorLog>(
        sortBy: [SortDescriptor(\DailyColorLog.date, order: .forward)]
    )
    descriptor.fetchLimit = 1
    return descriptor
}()

// MARK: - Preview

#Preview("타임라인") {
    TimelineGridView()
        .paletteTheme(.pantone)
        .preferredColorScheme(.light)
        .modelContainer(ColorLogStore.inMemory(seedDays: 140, palette: .pantone))
}

#Preview("타임라인 · 네온") {
    TimelineGridView()
        .paletteTheme(.triadic)
        .preferredColorScheme(.dark)
        .modelContainer(ColorLogStore.inMemory(seedDays: 140, palette: .triadic))
}
