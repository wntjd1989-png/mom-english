import AppIntents
import SwiftUI
import WidgetKit

/// 제어 센터 · 잠금화면 · 액션 버튼에 놓는 컨트롤 (iOS 18 이상).
///
/// 컨트롤 하나가 네트워크 하나에 대응합니다. 여러 개 쓰고 싶으면
/// 제어 센터에서 이 컨트롤을 여러 번 추가하고 각각 다른 네트워크를 지정하세요.
@available(iOS 18.0, *)
struct QuickConnectControl: ControlWidget {

    static let kind = "\(AppGroup.bundleRoot).quickconnect"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetButton(action: ConnectToNetworkIntent(network: value.network)) {
                Label(value.title, systemImage: value.symbol)
            }
        }
        .displayName("Wi-Fi 전환")
        .description("저장한 Wi-Fi 로 바로 연결합니다.")
    }
}

@available(iOS 18.0, *)
extension QuickConnectControl {

    struct Value {
        var network: NetworkEntity?
        var title: String
        var symbol: String
    }

    struct Provider: AppIntentControlValueProvider {

        func previewValue(configuration: SelectNetworkControlIntent) -> Value {
            Value(
                network: configuration.network,
                title: configuration.network?.name ?? "Wi-Fi 전환",
                symbol: configuration.network?.symbol ?? "wifi"
            )
        }

        func currentValue(configuration: SelectNetworkControlIntent) async throws -> Value {
            // 컨트롤 설정 당시의 스냅샷이 아니라 저장소의 최신 값을 읽습니다.
            // 앱에서 별칭·아이콘을 바꿔도 컨트롤에 반영됩니다.
            guard
                let selected = configuration.network,
                let stored = NetworkStore.shared.network(withID: selected.id)
            else {
                return Value(
                    network: configuration.network,
                    title: "네트워크 선택",
                    symbol: "wifi.exclamationmark"
                )
            }

            // 지금 붙어 있는 네트워크면 체크 표시가 들어간 심볼로 바꿔 상태를 알립니다.
            let isCurrent = NetworkStore.shared.cachedCurrentSSID == stored.ssid
            return Value(
                network: NetworkEntity(stored),
                title: stored.displayName,
                symbol: isCurrent ? "checkmark.circle.fill" : stored.symbol
            )
        }
    }
}
