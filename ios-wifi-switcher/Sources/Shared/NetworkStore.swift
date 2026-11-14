import Foundation
import WidgetKit

/// 저장된 Wi-Fi 목록의 단일 진실 공급원.
///
/// App Group 공유 `UserDefaults` 에 JSON 으로 보관합니다. 앱 본체가 쓰고,
/// 위젯/컨트롤 확장이 읽습니다. 쓰기가 끝나면 위젯 타임라인을 갱신합니다.
final class NetworkStore {

    static let shared = NetworkStore()

    private enum Key {
        static let networks = "networks.v1"
        static let cachedSSID = "cachedCurrentSSID"
        static let cachedSSIDDate = "cachedCurrentSSIDDate"
        static let cachedLatitude = "cachedLatitude"
        static let cachedLongitude = "cachedLongitude"
        static let cachedLocationDate = "cachedLocationDate"
        static let openSettingsOnFailure = "openSettingsOnFailure"
        static let locationSortEnabled = "locationSortEnabled"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = AppGroup.sharedDefaults) {
        self.defaults = defaults
    }

    // MARK: - 네트워크 목록

    func load() -> [SavedNetwork] {
        guard let data = defaults.data(forKey: Key.networks) else { return [] }
        guard let decoded = try? decoder.decode([SavedNetwork].self, from: data) else { return [] }
        return decoded.sorted { $0.sortIndex < $1.sortIndex }
    }

    func save(_ networks: [SavedNetwork]) {
        // sortIndex 를 항상 0..n-1 로 정규화해 두면 재정렬 로직이 단순해집니다.
        var normalized = networks
        for index in normalized.indices {
            normalized[index].sortIndex = index
        }
        guard let data = try? encoder.encode(normalized) else { return }
        defaults.set(data, forKey: Key.networks)
        reloadWidgets()
    }

    func network(withID id: UUID) -> SavedNetwork? {
        load().first { $0.id == id }
    }

    /// 새로 추가하거나 기존 항목을 갱신합니다.
    func upsert(_ network: SavedNetwork) {
        var networks = load()
        if let index = networks.firstIndex(where: { $0.id == network.id }) {
            networks[index] = network
        } else {
            var appended = network
            appended.sortIndex = networks.count
            networks.append(appended)
        }
        save(networks)
    }

    /// 목록과 키체인 비밀번호를 함께 지웁니다.
    func delete(id: UUID) {
        var networks = load()
        networks.removeAll { $0.id == id }
        save(networks)
        KeychainStore.delete(id: id)
    }

    /// 연결 성공 시 통계와 좌표를 갱신합니다.
    /// 좌표는 이미 지정돼 있으면 덮어쓰지 않습니다(사용자가 손으로 정한 값 보호).
    func recordSuccessfulConnect(id: UUID, latitude: Double? = nil, longitude: Double? = nil) {
        var networks = load()
        guard let index = networks.firstIndex(where: { $0.id == id }) else { return }
        networks[index].lastConnectedAt = Date()
        networks[index].connectCount += 1
        if !networks[index].hasCoordinate, let latitude, let longitude {
            networks[index].latitude = latitude
            networks[index].longitude = longitude
        }
        save(networks)
    }

    // MARK: - 현재 연결된 Wi-Fi 캐시
    //
    // 위젯 확장 프로세스에서는 `NEHotspotNetwork.fetchCurrent` 가 위치 권한 때문에
    // 신뢰성 있게 동작하지 않습니다. 그래서 앱이 읽을 때마다 여기에 적어 두고,
    // 위젯은 "마지막으로 확인된 값 + 확인 시각"을 보여 줍니다.

    var cachedCurrentSSID: String? {
        get { defaults.string(forKey: Key.cachedSSID) }
        set {
            defaults.set(newValue, forKey: Key.cachedSSID)
            defaults.set(Date(), forKey: Key.cachedSSIDDate)
            reloadWidgets()
        }
    }

    var cachedCurrentSSIDDate: Date? {
        defaults.object(forKey: Key.cachedSSIDDate) as? Date
    }

    // MARK: - 위치 캐시 (위치 기반 정렬 폴백)

    func cacheLocation(latitude: Double, longitude: Double) {
        defaults.set(latitude, forKey: Key.cachedLatitude)
        defaults.set(longitude, forKey: Key.cachedLongitude)
        defaults.set(Date(), forKey: Key.cachedLocationDate)
    }

    var cachedLocation: (latitude: Double, longitude: Double, date: Date)? {
        guard
            let date = defaults.object(forKey: Key.cachedLocationDate) as? Date,
            defaults.object(forKey: Key.cachedLatitude) != nil,
            defaults.object(forKey: Key.cachedLongitude) != nil
        else { return nil }
        return (
            defaults.double(forKey: Key.cachedLatitude),
            defaults.double(forKey: Key.cachedLongitude),
            date
        )
    }

    // MARK: - 사용자 설정

    /// 전환 실패 시 설정 앱(Wi-Fi)으로 보낼지 여부.
    var opensSettingsOnFailure: Bool {
        get { defaults.object(forKey: Key.openSettingsOnFailure) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.openSettingsOnFailure) }
    }

    /// 위치 기반 자동 정렬 사용 여부.
    var isLocationSortEnabled: Bool {
        get { defaults.object(forKey: Key.locationSortEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Key.locationSortEnabled)
            reloadWidgets()
        }
    }

    // MARK: - 위젯 갱신

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
    }
}
