import AppIntents
import Foundation

/// 위젯 버튼 / 제어 센터 컨트롤 / 단축어에서 호출하는 "이 Wi-Fi 로 전환" 동작.
///
/// ## 왜 `openAppWhenRun = true` 인가
///
/// `NEHotspotConfigurationManager.apply` 는 **앱이 포그라운드일 때만** 동작합니다.
/// 위젯 확장 프로세스에서 직접 호출하면 iOS 가
/// `NEHotspotConfigurationError.applicationIsNotInForeground` 로 거부합니다.
/// 게다가 처음 연결하는 SSID 는 시스템이 "연결하겠습니까?" 알림을 띄우는데,
/// 확장 프로세스는 그 알림을 띄울 수 없습니다.
///
/// 그래서 이 인텐트는 앱을 띄운 뒤 **앱 프로세스 안에서** `perform()` 을 실행합니다.
/// 사용자 입장에서는 "위젯 한 번 탭 → 앱이 잠깐 떴다가 전환 완료"로 보입니다.
/// iOS 에서 이보다 더 짧은 경로는 (탈옥 없이는) 존재하지 않습니다.
struct ConnectToNetworkIntent: AppIntent {

    static var title: LocalizedStringResource = "Wi-Fi 전환"

    static var description = IntentDescription(
        "저장해 둔 Wi-Fi 로 바로 전환합니다. iOS 제약 때문에 전환은 앱이 화면에 떠 있는 동안 처리됩니다."
    )

    /// 앱을 띄우고 그 프로세스에서 `perform()` 을 실행합니다. 위 주석 참고.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "네트워크")
    var network: NetworkEntity?

    init() {}

    init(network: NetworkEntity?) {
        self.network = network
    }

    init(networkID: UUID) {
        if let stored = NetworkStore.shared.network(withID: networkID) {
            self.network = NetworkEntity(stored)
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let network, let stored = NetworkStore.shared.network(withID: network.id) else {
            // 위젯이 설정된 뒤 네트워크를 지운 경우.
            return .result(dialog: "연결할 네트워크를 찾을 수 없습니다. 앱에서 다시 선택해 주세요.")
        }

        // 앱 UI 가 진행 상황을 보여줄 수 있도록 요청을 공유 상태에 남기고 알림을 보냅니다.
        PendingConnectRequest.set(id: stored.id)
        ConnectEvents.postStart(networkID: stored.id)

        do {
            let outcome = try await WiFiConnector.connect(to: stored)
            NetworkStore.shared.recordSuccessfulConnect(id: stored.id)
            PendingConnectRequest.clear()

            let message: String
            switch outcome {
            case .connected(let ssid):
                message = "\(ssid) 에 연결했습니다."
            case .alreadyConnected(let ssid):
                message = "이미 \(ssid) 에 연결되어 있습니다."
            case .appliedButUnverified(let ssid):
                message = "\(ssid) 로 전환을 요청했습니다."
            }
            ConnectEvents.postFinish(networkID: stored.id, message: message, isFailure: false)
            return .result(dialog: "\(message)")
        } catch {
            PendingConnectRequest.clear()
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let shouldOfferSettings = (error as? WiFiConnectError)?.suggestsOpeningSettings ?? true
            ConnectEvents.postFinish(
                networkID: stored.id,
                message: message,
                isFailure: true,
                offersSettings: shouldOfferSettings
            )
            return .result(dialog: "\(message)")
        }
    }
}

/// 위젯 탭 → 앱 실행 사이에 "무엇을 연결하려던 것인지"를 넘기는 통로.
/// 앱 UI 가 이 값을 읽어 진행 중 표시를 띄웁니다.
enum PendingConnectRequest {

    private static let key = "pendingConnectNetworkID"

    static func set(id: UUID) {
        AppGroup.sharedDefaults.set(id.uuidString, forKey: key)
    }

    static func clear() {
        AppGroup.sharedDefaults.removeObject(forKey: key)
    }

    static var current: UUID? {
        guard let raw = AppGroup.sharedDefaults.string(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }
}

/// 제어 센터 컨트롤을 "어떤 네트워크용"으로 설정할지 고르는 인텐트.
/// (iOS 18 컨트롤은 설정값을 이 타입으로 받습니다.)
struct SelectNetworkControlIntent: ControlConfigurationIntent {

    static var title: LocalizedStringResource = "Wi-Fi 컨트롤 설정"

    static var description = IntentDescription("제어 센터 버튼에 연결할 Wi-Fi 를 고릅니다.")

    @Parameter(title: "네트워크")
    var network: NetworkEntity?

    init() {}

    init(network: NetworkEntity?) {
        self.network = network
    }
}

/// 인텐트(앱 프로세스에서 실행됨)와 앱 UI 사이의 느슨한 연결.
/// 위젯에서 들어온 전환 요청의 진행/결과를 화면에 띄우는 데 씁니다.
enum ConnectEvents {

    static let didStart = Notification.Name("WiFiSwitcher.connectDidStart")
    static let didFinish = Notification.Name("WiFiSwitcher.connectDidFinish")

    enum UserInfoKey {
        static let networkID = "networkID"
        static let message = "message"
        static let isFailure = "isFailure"
        static let offersSettings = "offersSettings"
    }

    static func postStart(networkID: UUID) {
        NotificationCenter.default.post(
            name: didStart,
            object: nil,
            userInfo: [UserInfoKey.networkID: networkID]
        )
    }

    static func postFinish(
        networkID: UUID,
        message: String,
        isFailure: Bool,
        offersSettings: Bool = false
    ) {
        NotificationCenter.default.post(
            name: didFinish,
            object: nil,
            userInfo: [
                UserInfoKey.networkID: networkID,
                UserInfoKey.message: message,
                UserInfoKey.isFailure: isFailure,
                UserInfoKey.offersSettings: offersSettings,
            ]
        )
    }
}
