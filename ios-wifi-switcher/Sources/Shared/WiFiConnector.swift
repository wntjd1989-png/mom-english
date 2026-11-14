import Foundation
import NetworkExtension

/// Wi-Fi 전환 결과.
enum WiFiConnectOutcome: Sendable {
    /// 요청한 SSID 에 붙은 것까지 확인됨.
    case connected(ssid: String)
    /// 이미 그 네트워크에 붙어 있었음.
    case alreadyConnected(ssid: String)
    /// iOS 가 설정을 받아들였지만 실제 결합 여부를 확인하지 못함.
    /// (위치 권한이 없으면 현재 SSID 를 읽을 수 없어서 여기로 떨어집니다.)
    case appliedButUnverified(ssid: String)
}

enum WiFiConnectError: LocalizedError {
    case missingPassphrase
    case emptySSID
    case userDenied
    case invalidPassphrase
    case unsupported
    case notInForeground
    case joinedWrongNetwork(expected: String, actual: String)
    case system(Error)

    var errorDescription: String? {
        switch self {
        case .missingPassphrase:
            return "비밀번호가 저장되어 있지 않습니다. 네트워크를 편집해서 비밀번호를 입력해 주세요."
        case .emptySSID:
            return "Wi-Fi 이름(SSID)이 비어 있습니다."
        case .userDenied:
            return "연결 요청을 취소했습니다. 시스템 알림에서 '연결'을 눌러 주세요."
        case .invalidPassphrase:
            return "비밀번호 형식이 올바르지 않습니다. (WPA 는 8~63자, WEP 는 5자 또는 13자)"
        case .unsupported:
            return "이 기기 또는 iOS 버전에서는 Wi-Fi 설정 기능을 쓸 수 없습니다."
        case .notInForeground:
            return "iOS 는 앱이 화면에 떠 있을 때만 Wi-Fi 전환을 허용합니다. 앱을 열어 둔 상태에서 다시 시도해 주세요."
        case .joinedWrongNetwork(let expected, let actual):
            return "'\(expected)' 에 붙지 못했습니다. 현재 '\(actual)' 에 연결되어 있습니다. 신호가 잡히는 범위인지 확인해 주세요."
        case .system(let error):
            return error.localizedDescription
        }
    }

    /// 설정 앱으로 보내는 게 도움이 되는 상황인지.
    var suggestsOpeningSettings: Bool {
        switch self {
        case .joinedWrongNetwork, .system, .unsupported, .notInForeground:
            return true
        case .missingPassphrase, .emptySSID, .userDenied, .invalidPassphrase:
            return false
        }
    }
}

/// `NEHotspotConfigurationManager` 래퍼.
///
/// ⚠️ iOS 제약 2가지를 꼭 기억하세요.
///  1. 주변 Wi-Fi 목록을 **스캔할 수 없습니다.** 반드시 SSID 를 미리 알고 있어야 합니다.
///     (스캔은 `NEHotspotHelper` 엔타이틀먼트가 필요하고, Apple 이 통신사급에만 승인합니다.)
///  2. `apply` 는 앱이 **포그라운드**에 있을 때만 안정적으로 동작합니다.
///     그래서 위젯 버튼은 앱을 띄운 뒤 전환합니다 (`ConnectToNetworkIntent` 참고).
enum WiFiConnector {

    /// 저장된 네트워크로 전환합니다.
    static func connect(to network: SavedNetwork) async throws -> WiFiConnectOutcome {
        let ssid = network.ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ssid.isEmpty else { throw WiFiConnectError.emptySSID }

        // 이미 붙어 있으면 시스템 알림을 띄우지 않고 바로 끝냅니다.
        if let current = await CurrentNetworkReader.currentSSID(), current == ssid {
            NetworkStore.shared.cachedCurrentSSID = current
            return .alreadyConnected(ssid: ssid)
        }

        let configuration = try makeConfiguration(for: network, ssid: ssid)

        // `apply` 가 alreadyAssociated 를 돌려주면 이미 붙어 있다는 뜻이므로 성공입니다.
        if try await apply(configuration) == .alreadyAssociated {
            NetworkStore.shared.cachedCurrentSSID = ssid
            return .alreadyConnected(ssid: ssid)
        }

        // `apply` 성공은 "설정이 등록됐다"는 뜻일 뿐, 결합 완료를 보장하지 않습니다.
        // 실제로 붙었는지 짧게 폴링해서 확인합니다.
        guard let joined = await CurrentNetworkReader.waitForSSID(timeout: 6) else {
            return .appliedButUnverified(ssid: ssid)
        }

        NetworkStore.shared.cachedCurrentSSID = joined
        guard joined == ssid else {
            throw WiFiConnectError.joinedWrongNetwork(expected: ssid, actual: joined)
        }
        return .connected(ssid: ssid)
    }

    /// 이 앱이 등록한 Wi-Fi 설정을 제거합니다.
    /// (앱을 삭제해도 자동으로 제거되지만, 사용자가 직접 정리할 수 있게 열어 둡니다.)
    static func forget(ssid: String) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
    }

    /// 이 앱이 등록해 둔 SSID 목록.
    static func managedSSIDs() async -> [String] {
        await withCheckedContinuation { continuation in
            NEHotspotConfigurationManager.shared.getConfiguredSSIDs { ssids in
                continuation.resume(returning: ssids)
            }
        }
    }

    // MARK: - 내부

    private static func makeConfiguration(
        for network: SavedNetwork,
        ssid: String
    ) throws -> NEHotspotConfiguration {
        let configuration: NEHotspotConfiguration

        switch network.security {
        case .open:
            configuration = NEHotspotConfiguration(ssid: ssid)
        case .wep, .wpa:
            guard let passphrase = KeychainStore.passphrase(for: network.id), !passphrase.isEmpty else {
                throw WiFiConnectError.missingPassphrase
            }
            configuration = NEHotspotConfiguration(
                ssid: ssid,
                passphrase: passphrase,
                isWEP: network.security == .wep
            )
        }

        // `false` 로 두면 설정이 남아 있어서 다음부터는 시스템 알림 없이 붙습니다.
        configuration.joinOnce = false
        configuration.hidden = network.isHidden
        return configuration
    }

    private enum ApplyResult: Equatable {
        case applied
        /// iOS 가 "이미 그 네트워크에 결합되어 있다"고 응답한 경우. 오류가 아닙니다.
        case alreadyAssociated
    }

    private static func apply(_ configuration: NEHotspotConfiguration) async throws -> ApplyResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ApplyResult, Error>) in
            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                guard let error else {
                    continuation.resume(returning: .applied)
                    return
                }
                if isAlreadyAssociated(error) {
                    continuation.resume(returning: .alreadyAssociated)
                    return
                }
                continuation.resume(throwing: translate(error))
            }
        }
    }

    private static func isAlreadyAssociated(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NEHotspotConfigurationErrorDomain
            && nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue
    }

    private static func translate(_ error: Error) -> WiFiConnectError {
        let nsError = error as NSError
        guard nsError.domain == NEHotspotConfigurationErrorDomain,
              let code = NEHotspotConfigurationError(rawValue: nsError.code)
        else {
            return .system(error)
        }

        switch code {
        case .alreadyAssociated:
            // 호출부에서 이미 성공으로 걸러내므로 여기까지 오지 않는 게 정상입니다.
            return .system(error)
        case .userDenied:
            return .userDenied
        case .invalidWPAPassphrase, .invalidWEPPassphrase:
            return .invalidPassphrase
        case .unsupported:
            return .unsupported
        case .applicationIsNotInForeground:
            // 위젯/컨트롤 확장 프로세스에서 직접 호출했을 때 나오는 코드입니다.
            return .notInForeground
        default:
            return .system(error)
        }
    }
}
