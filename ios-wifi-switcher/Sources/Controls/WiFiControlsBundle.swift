import SwiftUI
import WidgetKit

@main
struct WiFiControlsBundle: WidgetBundle {

    var body: some Widget {
        // 홈 화면 / 잠금화면 위젯
        WiFiListWidget()

        // 제어 센터 · 잠금화면 · 액션 버튼 컨트롤 (iOS 18 이상)
        if #available(iOS 18.0, *) {
            QuickConnectControl()
        }
    }
}
