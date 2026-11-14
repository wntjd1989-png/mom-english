import Foundation

/// Wi-Fi 보안 방식. `NEHotspotConfiguration` 생성자가 요구하는 세 갈래와 1:1 대응합니다.
enum WiFiSecurity: String, Codable, CaseIterable, Sendable, Identifiable {
    /// 비밀번호 없는 개방형 네트워크
    case open
    /// WEP (구형 공유기)
    case wep
    /// WPA / WPA2 / WPA3 — 대부분의 가정·사무실 공유기
    case wpa

    var id: String { rawValue }

    var requiresPassphrase: Bool { self != .open }

    var displayName: String {
        switch self {
        case .open: return "비밀번호 없음"
        case .wep:  return "WEP"
        case .wpa:  return "WPA / WPA2 / WPA3"
        }
    }
}

/// 사용자가 앱에 등록해 둔 Wi-Fi 한 개.
///
/// 비밀번호는 이 구조체에 담지 않습니다. 평문이 `UserDefaults` 에 남지 않도록
/// 키체인(`KeychainStore`)에 `id` 를 키로 따로 저장합니다.
struct SavedNetwork: Codable, Identifiable, Hashable, Sendable {

    var id: UUID
    /// 실제 Wi-Fi 이름(SSID). 대소문자까지 정확히 일치해야 연결됩니다.
    var ssid: String
    /// 사용자가 붙인 별칭. 예) "집", "회사 5G", "엄마폰 핫스팟"
    var label: String
    /// SF Symbols 이름. 위젯 버튼 아이콘으로 씁니다.
    var symbol: String
    /// 버튼 색상 (hex, "#RRGGBB")
    var tintHex: String
    var security: WiFiSecurity
    /// 숨겨진(SSID 브로드캐스트 안 하는) 네트워크 여부
    var isHidden: Bool

    /// 이 Wi-Fi 를 쓰는 장소의 좌표. 위치 기반 자동 정렬에 사용합니다.
    /// 연결에 성공할 때 현재 위치를 기록해 두거나, 편집 화면에서 직접 지정합니다.
    var latitude: Double?
    var longitude: Double?

    var lastConnectedAt: Date?
    var connectCount: Int
    /// 사용자가 손으로 정한 순서. 위치 정보가 없을 때의 기본 정렬 기준입니다.
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        ssid: String = "",
        label: String = "",
        symbol: String = "wifi",
        tintHex: String = "#0A84FF",
        security: WiFiSecurity = .wpa,
        isHidden: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil,
        lastConnectedAt: Date? = nil,
        connectCount: Int = 0,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.ssid = ssid
        self.label = label
        self.symbol = symbol
        self.tintHex = tintHex
        self.security = security
        self.isHidden = isHidden
        self.latitude = latitude
        self.longitude = longitude
        self.lastConnectedAt = lastConnectedAt
        self.connectCount = connectCount
        self.sortIndex = sortIndex
    }

    /// 화면·위젯에 표시할 이름. 별칭이 비어 있으면 SSID 를 씁니다.
    var displayName: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ssid : trimmed
    }

    var hasCoordinate: Bool { latitude != nil && longitude != nil }

    /// 연결을 시도할 수 있는 최소 조건을 갖췄는지.
    var isComplete: Bool {
        !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 위젯/컨트롤에 넘기기 전에 쓰는 가벼운 표현.
/// 좌표·카운터 같은 건 위젯에서 필요 없으므로 떼어 냅니다.
struct NetworkSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var displayName: String
    var ssid: String
    var symbol: String
    var tintHex: String

    init(_ network: SavedNetwork) {
        self.id = network.id
        self.displayName = network.displayName
        self.ssid = network.ssid
        self.symbol = network.symbol
        self.tintHex = network.tintHex
    }
}
