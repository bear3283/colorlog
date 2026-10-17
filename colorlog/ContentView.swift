import SwiftUI
import SwiftData
import WidgetKit

@main struct MyApp: App {
    /// 알림 delegate는 앱이 실행을 마치기 전에 지정돼야 해서 AppDelegate가 필요하다.
    @UIApplicationDelegateAdaptor(ColorLogAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(ColorLogStore.shared)
    }
}

struct ContentView: View {

    /// 선택한 팔레트는 `Palette.id`로 영속된다.
    /// `@AppStorage`는 String을 다루므로 팔레트로 푸는 건 이 경계에서 한 번만 한다.
    @AppStorage(ColorLogStore.paletteKey, store: ColorLogStore.defaults)
    private var paletteID = Palette.default.id
    /// 홈 화면 아이콘까지 팔레트를 따라가게 할지.
    /// 기본값 false — iOS는 아이콘이 바뀔 때마다 시스템 알림을 띄운다.
    /// 팔레트를 구경하는 것만으로 알림이 쏟아지면 안 되므로 켜는 건 사용자의 선택으로 둔다.
    @AppStorage("colorlog.syncAppIcon", store: ColorLogStore.defaults)
    private var syncsAppIcon = false

    @State private var isShowingSettings = false
    /// 나만의 팔레트의 다섯 색. 바뀌면 틴트 · 위쪽 팔레트 점들이 따라 다시 그려진다.
    @AppStorage(CustomPalette.key, store: ColorLogStore.defaults) private var customHexes = ""
    @Environment(\.scenePhase) private var scenePhase

    private let router = NotificationRouter.shared
    private let reminders = ReminderStore.shared

    private var palette: Palette {
        // customHexes를 읽어 두어야 나만의 팔레트 색이 바뀔 때 이 화면이 다시 그려진다.
        _ = customHexes
        return Palette.resolve(paletteID)
    }

    var body: some View {
        TimelineGridView(
            onOpenSettings: { isShowingSettings = true },
            openRequest: Bindable(router).requestedDate
        )
        .paletteTheme(palette)
        // DatePicker 같은 시스템 컨트롤도 앱의 언어를 따르게 한다.
        // (없으면 한국어 화면 안에 "8:00 AM"이 섞인다)
        .environment(\.locale, .colorLog)
        // 팔레트를 바꾸면 배경·틴트·빈 칸 질감이 한꺼번에 넘어간다.
        .animation(.smooth(duration: 0.5), value: palette)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(selection: $paletteID, syncsAppIcon: $syncsAppIcon)
                .paletteTheme(palette)
                .environment(\.locale, .colorLog)
        }
        .task {
            ColorLogStore.registerFirstUseIfNeeded()
            // iOS 설정에서 알림을 껐다 켜고 돌아올 수 있으므로 매번 확인하고 다시 건다.
            await reminders.refreshAuthorization()
            await reminders.reschedule()
            // onChange만으로는 '설정은 켜져 있는데 아이콘이 어긋난 채 시작'하는
            // 경우(기기 복원, 앱 재설치)를 맞추지 못한다.
            applyAppIcon(for: palette)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await reminders.refreshAuthorization()
                await reminders.reschedule()
            }
        }
        .onChange(of: palette) { _, newPalette in
            applyAppIcon(for: newPalette)
            // 위젯은 별도 프로세스라 테마가 바뀐 걸 스스로 알 수 없다.
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: syncsAppIcon) { _, _ in
            applyAppIcon(for: palette)
        }
    }

    /// 홈 화면 아이콘을 현재 팔레트에 맞춘다.
    /// 이미 같은 아이콘이면 호출하지 않는다 — 불필요한 시스템 알림을 막기 위해.
    private func applyAppIcon(for palette: Palette) {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else { return }

        let desired = syncsAppIcon ? palette.alternateIconName : nil
        guard application.alternateIconName != desired else { return }

        Task {
            try? await application.setAlternateIconName(desired)
        }
    }
}

#Preview("컬러로그") {
    ContentView()
        .modelContainer(ColorLogStore.inMemory(seedDays: 0))
}
