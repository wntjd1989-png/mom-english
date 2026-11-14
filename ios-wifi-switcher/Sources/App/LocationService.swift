import CoreLocation
import Foundation

/// 위치 기반 자동 정렬에 쓰는 한 방 측위 래퍼.
///
/// 위치가 필요한 이유는 두 가지입니다.
///  1. `NEHotspotNetwork.fetchCurrent` (현재 SSID 읽기) 가 위치 권한을 요구합니다.
///  2. 등록해 둔 장소와의 거리로 목록을 정렬합니다.
@MainActor
final class LocationService: NSObject, ObservableObject {

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastLocation: CLLocation?

    private let manager = CLLocationManager()
    private var pendingContinuations: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        // super.init() 보다 먼저 self(= manager)를 읽을 수 없으므로
        // 실제 권한 상태는 super.init() 이후에 채웁니다.
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// 현재 위치를 한 번 받아옵니다. 권한이 없거나 실패하면 `nil`.
    func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }

        // 2분 안에 받은 위치가 있으면 재사용합니다. 측위 비용과 대기 시간을 아낍니다.
        if let lastLocation, Date().timeIntervalSince(lastLocation.timestamp) < 120 {
            return lastLocation
        }

        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
            manager.requestLocation()
        }
    }

    private func resumePending(with location: CLLocation?) {
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: location)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 델리게이트 콜백은 nonisolated 이므로 상태를 값으로 꺼내 MainActor 로 넘깁니다.
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            if !isAuthorized {
                resumePending(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            let location = locations.last
            if let location {
                lastLocation = location
                // 위젯이 쓸 수 있도록 공유 저장소에 적어 둡니다.
                NetworkStore.shared.cacheLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            resumePending(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            resumePending(with: nil)
        }
    }
}
