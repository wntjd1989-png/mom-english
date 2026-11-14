import Foundation
import CoreLocation

/// 저장된 네트워크를 "지금 여기서 쓸 가능성이 높은 순"으로 정렬합니다.
///
/// iOS 가 주변 Wi-Fi 스캔을 막아 두었기 때문에 "신호가 잡히는 순서"는 알 수 없습니다.
/// 대신 각 네트워크를 등록/연결한 장소의 좌표를 기억해 두고, 현재 위치에서 가까운 것을
/// 위로 올립니다. 실용적으로는 "집에 오면 집 Wi-Fi 가 맨 위"로 동작합니다.
enum NetworkRanker {

    /// 이 거리 안쪽이면 "여기 있는 네트워크"로 간주합니다. (미터)
    static let nearbyRadius: CLLocationDistance = 150

    struct RankedNetwork: Identifiable, Hashable {
        var network: SavedNetwork
        /// 현재 위치로부터의 거리(미터). 좌표가 없거나 위치를 모르면 `nil`.
        var distance: CLLocationDistance?

        var id: UUID { network.id }

        var isNearby: Bool {
            guard let distance else { return false }
            return distance <= NetworkRanker.nearbyRadius
        }

        /// "120m", "1.4km" 같은 짧은 표기.
        var distanceText: String? {
            guard let distance else { return nil }
            if distance < 1000 {
                return "\(Int(distance.rounded()))m"
            }
            return String(format: "%.1fkm", distance / 1000)
        }
    }

    /// - Parameters:
    ///   - networks: 저장된 전체 목록
    ///   - location: 현재 위치. `nil` 이면 위치 정렬을 건너뛰고 사용자 순서를 유지합니다.
    ///   - currentSSID: 지금 붙어 있는 Wi-Fi. 있으면 항상 맨 위로 올립니다.
    static func rank(
        _ networks: [SavedNetwork],
        location: CLLocation?,
        currentSSID: String? = nil
    ) -> [RankedNetwork] {
        let ranked = networks.map { network -> RankedNetwork in
            guard
                let location,
                let latitude = network.latitude,
                let longitude = network.longitude
            else {
                return RankedNetwork(network: network, distance: nil)
            }
            let target = CLLocation(latitude: latitude, longitude: longitude)
            return RankedNetwork(network: network, distance: location.distance(from: target))
        }

        return ranked.sorted { lhs, rhs in
            // 1순위: 지금 연결된 네트워크
            let lhsIsCurrent = currentSSID != nil && lhs.network.ssid == currentSSID
            let rhsIsCurrent = currentSSID != nil && rhs.network.ssid == currentSSID
            if lhsIsCurrent != rhsIsCurrent { return lhsIsCurrent }

            // 2순위: 거리를 아는 쪽이 모르는 쪽보다 위
            switch (lhs.distance, rhs.distance) {
            case let (left?, right?):
                if left != right { return left < right }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            // 3순위: 사용자가 정한 순서
            return lhs.network.sortIndex < rhs.network.sortIndex
        }
    }

    /// 위젯처럼 `CLLocation` 을 만들기 번거로운 곳에서 쓰는 편의 함수.
    static func rank(
        _ networks: [SavedNetwork],
        cachedLocation: (latitude: Double, longitude: Double, date: Date)?,
        currentSSID: String? = nil
    ) -> [RankedNetwork] {
        let location = cachedLocation.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }
        return rank(networks, location: location, currentSSID: currentSSID)
    }
}
