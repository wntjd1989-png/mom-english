import AppIntents
import SwiftUI
import WidgetKit

/// 홈 화면 위젯. 저장된 Wi-Fi 를 버튼 격자로 보여 주고, 탭하면 전환합니다.
///
/// 버튼은 `ConnectToNetworkIntent` 를 실행합니다. 그 인텐트는 앱을 띄운 뒤
/// 앱 프로세스에서 전환을 수행합니다(iOS 가 확장 프로세스에서의 전환을 금지).
struct WiFiListWidget: Widget {

    static let kind = "WiFiListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WiFiTimelineProvider()) { entry in
            WiFiListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wi-Fi 전환")
        .description("저장한 Wi-Fi 를 탭 한 번으로 전환합니다.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
    }
}

// MARK: - 타임라인

struct WiFiEntry: TimelineEntry {
    var date: Date
    var networks: [NetworkSnapshot]
    /// 마지막으로 확인된 연결 SSID. 앱이 포그라운드일 때 갱신됩니다.
    var currentSSID: String?
    /// `currentSSID` 를 확인한 시각. 너무 오래됐으면 표시를 흐리게 합니다.
    var currentSSIDDate: Date?
    /// App Group 이 설정되지 않아 목록을 읽을 수 없는 상태
    var isMisconfigured: Bool = false

    var isCurrentSSIDStale: Bool {
        guard let currentSSIDDate else { return true }
        return Date().timeIntervalSince(currentSSIDDate) > 60 * 30
    }
}

struct WiFiTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> WiFiEntry {
        WiFiEntry(
            date: Date(),
            networks: [
                NetworkSnapshot(SavedNetwork(ssid: "집", label: "집", symbol: "house.fill")),
                NetworkSnapshot(SavedNetwork(ssid: "회사", label: "회사", symbol: "building.2.fill", tintHex: "#30D158")),
            ],
            currentSSID: "집"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WiFiEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WiFiEntry>) -> Void) {
        let entry = makeEntry()
        // 보여 주는 내용은 앱이 바뀔 때 `reloadAllTimelines` 로 갱신됩니다.
        // 그래도 "확인 시각"이 늙는 걸 반영하려고 30분마다 한 번 다시 그립니다.
        let next = Date().addingTimeInterval(60 * 30)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> WiFiEntry {
        let store = NetworkStore.shared
        let networks = store.load()

        let ranked = store.isLocationSortEnabled
            ? NetworkRanker.rank(
                networks,
                cachedLocation: store.cachedLocation,
                currentSSID: store.cachedCurrentSSID
              ).map(\.network)
            : networks

        return WiFiEntry(
            date: Date(),
            networks: ranked.map(NetworkSnapshot.init),
            currentSSID: store.cachedCurrentSSID,
            currentSSIDDate: store.cachedCurrentSSIDDate,
            isMisconfigured: !AppGroup.isSharedDefaultsAvailable
        )
    }
}

// MARK: - 뷰

struct WiFiListWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let entry: WiFiEntry

    /// 패밀리별로 보여 줄 버튼 개수.
    private var capacity: Int {
        switch family {
        case .systemSmall:  return 2
        case .systemMedium: return 4
        case .systemLarge:  return 8
        default:            return 2
        }
    }

    private var columns: Int {
        switch family {
        case .systemSmall: return 1
        default:           return 2
        }
    }

    var body: some View {
        if entry.isMisconfigured {
            MessageView(
                icon: "exclamationmark.triangle.fill",
                title: "설정 필요",
                message: "앱과 위젯에 같은 App Group 을 추가해 주세요."
            )
        } else if entry.networks.isEmpty {
            MessageView(
                icon: "plus.circle",
                title: "등록된 Wi-Fi 없음",
                message: "앱을 열어 자주 쓰는 Wi-Fi 를 추가해 주세요."
            )
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            let shown = Array(entry.networks.prefix(capacity))
            let gridColumns = Array(
                repeating: GridItem(.flexible(), spacing: 8),
                count: columns
            )

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(shown) { network in
                    NetworkButton(
                        network: network,
                        isCurrent: network.ssid == entry.currentSSID,
                        isCompact: family == .systemSmall
                    )
                }
            }

            if entry.networks.count > capacity {
                Text("+\(entry.networks.count - capacity)개 더")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.currentSSID == nil ? "wifi.slash" : "wifi")
                .font(.caption2)
            Text(entry.currentSSID ?? "연결 확인 불가")
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(entry.isCurrentSSIDStale ? .tertiary : .secondary)
    }
}

/// 위젯의 네트워크 버튼 한 개. 탭하면 인텐트가 실행됩니다.
private struct NetworkButton: View {

    let network: NetworkSnapshot
    let isCurrent: Bool
    let isCompact: Bool

    var body: some View {
        Button(intent: ConnectToNetworkIntent(networkID: network.id)) {
            HStack(spacing: 6) {
                Image(systemName: network.symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(network.displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isCurrent {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, isCompact ? 10 : 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: network.tintHex).opacity(isCurrent ? 0.32 : 0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(hex: network.tintHex).opacity(isCurrent ? 0.9 : 0))
            )
            .foregroundStyle(Color(hex: network.tintHex))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(network.displayName) 에 연결")
    }
}

private struct MessageView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }
}
