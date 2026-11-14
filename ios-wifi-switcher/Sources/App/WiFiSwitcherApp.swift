import SwiftUI

@main
struct WiFiSwitcherApp: App {

    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task {
                    // 앱이 처음 떴을 때. 위젯 탭으로 실행된 경우도 여기를 지납니다.
                    await model.refreshEverything()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await model.refreshEverything() }
                }
        }
    }
}
