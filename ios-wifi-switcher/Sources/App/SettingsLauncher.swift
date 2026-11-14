import UIKit

/// 전환 실패 시 설정 앱으로 보내 주는 도우미.
enum SettingsLauncher {

    /// 설정 > Wi-Fi 로 직접 이동을 시도합니다.
    ///
    /// ⚠️ `App-Prefs:` 는 Apple 이 공식 지원하지 않는 비공개 스킴입니다.
    ///   - App Store 심사에서 거부 사유가 될 수 있습니다. (개인 설치용은 무관)
    ///   - iOS 버전에 따라 조용히 무시될 수 있습니다.
    /// 그래서 실패하면 앱 자체 설정 화면으로 폴백합니다. 거기서 한 번 더
    /// 뒤로 나가면 설정 최상단이라 Wi-Fi 까지 두 번 탭이면 도달합니다.
    @MainActor
    static func openWiFiSettings() {
        if let url = URL(string: "App-Prefs:root=WIFI"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        openAppSettings()
    }

    @MainActor
    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
