//
//  MonthPosterSheet.swift
//  colorlog
//
//  월간 곰 포스터를 미리 보고 공유하는 시트. 달을 앞뒤로 넘기고, 공유 버튼으로 이미지를 내보낸다.
//  내보내기만 한다 — 저장소에는 아무것도 쓰지 않는다.
//

import SwiftData
import SwiftUI

struct MonthPosterSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.paletteTheme) private var theme

    /// 보고 있는 달의 1일.
    @State private var month: Date
    @State private var image: UIImage?
    @State private var poster: MonthPoster?

    private let calendar = Calendar.current

    init(month: Date = .now) {
        let start = Calendar.current.dateInterval(of: .month, for: month)?.start ?? month
        _month = State(initialValue: start)
    }

    private var thisMonth: Date { calendar.dateInterval(of: .month, for: .now)?.start ?? .now }
    private var canGoForward: Bool { month < thisMonth }

    private var title: String {
        String(localized: "\(month.formatted(.dateTime.year().month(.wide).locale(.colorLog))) 곰 포스터",
               comment: "월간 곰 포스터 공유 제목. 연 · 월")
    }

    var body: some View {
        VStack(spacing: 18) {
            monthSwitcher
            posterPreview
            shareButton
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.background)
        .presentationBackground(theme.background)
        .presentationDragIndicator(.visible)
        .task(id: month) { render() }
    }

    private var monthSwitcher: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("이전 달")
            Spacer()
            Text(month.formatted(.dateTime.year().month(.wide).locale(.colorLog)))
                .font(.gaegu(size: 24))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("다음 달")
        }
        .font(.system(size: 18, weight: .semibold))
        .tint(theme.tint)
        .foregroundStyle(theme.tint)
    }

    @ViewBuilder
    private var posterPreview: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(MonthPosterView.size.width / MonthPosterView.size.height, contentMode: .fit)
        .frame(maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(poster.map { String(localized: "칠한 날 \($0.recordedDays)일") } ?? "")
    }

    @ViewBuilder
    private var shareButton: some View {
        if let image {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(title, image: Image(uiImage: image))
            ) {
                Label("포스터 공유", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(theme.background)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(theme.tint, in: .capsule)
            }
        } else {
            Color.clear.frame(height: 50)
        }
    }

    private func step(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month), next <= thisMonth else { return }
        month = next
    }

    private func render() {
        // 저장소를 읽지 못하면 빈 달로 그린다(기록을 고치지 않으므로 잃을 것이 없다).
        let loaded = (try? MonthPoster.load(month: month, context: modelContext, calendar: calendar))
            ?? MonthPoster(month: month, records: [:], calendar: calendar)
        poster = loaded
        image = MonthPosterView(poster: loaded, calendar: calendar).rendered()
    }
}

#if DEBUG
#Preview("포스터 시트") {
    MonthPosterSheet()
        .modelContainer(ColorLogStore.inMemory(seedDays: 60, palette: Palette(preset: .pantone)))
        .paletteTheme(Palette(preset: .pantone))
}
#endif
