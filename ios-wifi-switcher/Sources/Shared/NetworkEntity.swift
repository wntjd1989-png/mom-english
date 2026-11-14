import AppIntents
import Foundation

/// 제어 센터 컨트롤 설정 화면에서 "어떤 Wi-Fi 에 연결할 컨트롤인가"를
/// 사용자가 고를 수 있게 해 주는 엔티티.
struct NetworkEntity: AppEntity, Identifiable, Hashable {

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Wi-Fi 네트워크")
    }

    static var defaultQuery = NetworkEntityQuery()

    var id: UUID
    var name: String
    var ssid: String
    var symbol: String
    var tintHex: String

    var displayRepresentation: DisplayRepresentation {
        // 삼항 연산자의 타입 추론이 모호해지지 않도록 타입을 명시합니다.
        let subtitle: LocalizedStringResource? = (name == ssid) ? nil : "\(ssid)"
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle,
            image: .init(systemName: symbol)
        )
    }

    init(_ network: SavedNetwork) {
        self.id = network.id
        self.name = network.displayName
        self.ssid = network.ssid
        self.symbol = network.symbol
        self.tintHex = network.tintHex
    }
}

struct NetworkEntityQuery: EntityQuery {

    func entities(for identifiers: [UUID]) async throws -> [NetworkEntity] {
        let stored = NetworkStore.shared.load()
        return identifiers.compactMap { id in
            stored.first { $0.id == id }.map(NetworkEntity.init)
        }
    }

    func suggestedEntities() async throws -> [NetworkEntity] {
        NetworkStore.shared.load().map(NetworkEntity.init)
    }
}
