import Foundation

/// 앱 본체와 위젯/컨트롤 확장이 공유하는 식별자 모음.
///
/// ⚠️ 중요: `teamPrefixedBundleRoot` 값은 본인의 번들 ID로 바꿔야 합니다.
/// `project.yml` 의 `BUNDLE_ID_ROOT` 와 **반드시 동일하게** 유지하세요.
/// 한 곳이라도 틀리면 위젯이 저장된 네트워크 목록을 읽지 못합니다.
enum AppGroup {

    /// 번들 ID 루트. 예) "com.example.wifiswitcher"
    /// Xcode 의 Signing & Capabilities 에서 만든 App Group 이름과 짝이 맞아야 합니다.
    static let bundleRoot = "com.example.wifiswitcher"

    /// App Group 식별자. 앱 타깃과 위젯 타깃 양쪽 entitlements 에 들어갑니다.
    static let identifier = "group.\(bundleRoot)"

    /// 키체인 액세스 그룹.
    ///
    /// iOS 는 App Group 식별자를 키체인 액세스 그룹으로 그대로 쓸 수 있게 허용합니다.
    /// 덕분에 `$(AppIdentifierPrefix)` 팀 접두사를 런타임에 알아낼 필요가 없습니다.
    static let keychainAccessGroup = identifier

    /// App Group 이 실제로 동작하는지 여부. 도움말 화면의 진단 항목에 씁니다.
    ///
    /// `UserDefaults(suiteName:)` 는 엔타이틀먼트가 없어도 non-nil 을 돌려주므로
    /// 진단에 쓸 수 없습니다. 반면 `containerURL(forSecurityApplicationGroupIdentifier:)`
    /// 는 해당 App Group 엔타이틀먼트가 없으면 `nil` 이라서 신뢰할 수 있습니다.
    static var isSharedDefaultsAvailable: Bool {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    /// 공유 UserDefaults.
    ///
    /// App Group 설정이 아직 안 된 상태(시뮬레이터 첫 실행 등)에서도
    /// 앱이 동작하도록 `.standard` 로 폴백합니다. 단 이 경우 위젯과는 공유되지 않습니다.
    static var sharedDefaults: UserDefaults {
        guard isSharedDefaultsAvailable, let shared = UserDefaults(suiteName: identifier) else {
            return .standard
        }
        return shared
    }
}
