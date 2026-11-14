import Foundation
import NetworkExtension

/// 현재 붙어 있는 Wi-Fi 이름을 읽습니다.
///
/// 필요 조건 (둘 다 없으면 항상 `nil` 입니다):
///  - `Access WiFi Information` 기능 (entitlement `com.apple.developer.networking.wifi-info`)
///  - 위치 권한 "앱을 사용하는 동안" 이상
///
/// 그래서 앱이 포그라운드에 있을 때만 신뢰할 수 있고,
/// 위젯은 `NetworkStore.cachedCurrentSSID` 에 적힌 마지막 값을 씁니다.
enum CurrentNetworkReader {

    static func fetchCurrent() async -> NEHotspotNetwork? {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: network)
            }
        }
    }

    static func currentSSID() async -> String? {
        await fetchCurrent()?.ssid
    }

    /// 현재 SSID 를 읽고 캐시에도 반영합니다.
    @discardableResult
    static func refreshCachedSSID() async -> String? {
        let ssid = await currentSSID()
        NetworkStore.shared.cachedCurrentSSID = ssid
        return ssid
    }

    /// Wi-Fi 결합에는 몇 초가 걸립니다. SSID 가 읽힐 때까지 짧게 폴링합니다.
    /// - Returns: 읽힌 SSID, 또는 제한 시간 안에 못 읽었으면 `nil`.
    static func waitForSSID(timeout: TimeInterval) async -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let ssid = await currentSSID(), !ssid.isEmpty {
                return ssid
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return nil
    }
}
