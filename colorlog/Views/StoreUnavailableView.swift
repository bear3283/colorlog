//
//  StoreUnavailableView.swift
//  colorlog
//
//  기록 저장소를 열지 못했을 때의 화면.
//
//  예전에는 이 경우 빈 저장소를 새로 만들어 조용히 넘어갔다. 사용자에게는 그게
//  '그동안의 곰이 전부 사라진 캔버스'로 보였다. 지금은 열지 못했다는 사실과
//  기록은 그대로 있다는 것, 그리고 해서는 안 되는 일(앱 지우기)을 알려 준다.
//

import SwiftUI

struct StoreUnavailableView: View {

    let failure: StoreOpenFailure
    let onRetry: () -> Void

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "tray.full")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("기록을 열지 못했어요")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                Text("그동안 남긴 색은 지우지 않고 이 기기에 그대로 두었어요.")
                Text("앱을 완전히 닫았다가 다시 열어 보세요. 기기 저장 공간이 부족하다면 공간을 비운 뒤 다시 시도해 주세요.")
                Text("이 화면이 계속 보여도 **앱을 지우지 마세요.** 앱을 지우면 기록도 함께 지워져요. 다음 업데이트를 기다리거나 앱 스토어 페이지로 문의해 주세요.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 420, alignment: .leading)

            Button {
                isRetrying = true
                onRetry()
                isRetrying = false
            } label: {
                Text("다시 시도")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRetrying)

            Spacer()

            Text("오류 코드 \(failure.diagnosticCode)")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .task {
            // 원본은 이미 그대로 있다. 혹시 다음 버전이 원본을 잘못 다루더라도 되살릴 수 있게 한 벌 더 둔다.
            guard failure.kind == .openFailed, let url = failure.storeURL else { return }
            _ = await Task.detached(priority: .utility) {
                ColorLogStore.preserveCopy(of: url)
            }.value
        }
    }
}

#Preview("저장소를 열지 못함") {
    StoreUnavailableView(
        failure: StoreOpenFailure(
            kind: .openFailed,
            storeURL: nil,
            underlying: NSError(domain: NSCocoaErrorDomain, code: 134504)
        ),
        onRetry: {}
    )
}
