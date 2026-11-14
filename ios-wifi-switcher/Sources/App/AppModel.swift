import Combine
import CoreLocation
import Foundation
import SwiftUI

/// 앱 화면 전체가 공유하는 상태.
@MainActor
final class AppModel: ObservableObject {

    /// 화면 하단에 띄우는 결과 배너.
    struct Banner: Identifiable, Equatable {
        enum Kind: Equatable { case success, failure, info }

        let id = UUID()
        var kind: Kind
        var message: String
        var offersSettings: Bool = false
    }

    @Published private(set) var ranked: [NetworkRanker.RankedNetwork] = []
    @Published private(set) var currentSSID: String?
    /// 지금 연결 시도 중인 네트워크 ID. 행에 스피너를 띄우는 데 씁니다.
    @Published private(set) var connectingID: UUID?
    @Published var banner: Banner?

    let location: LocationService
    private let store = NetworkStore.shared
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // LocationService.init 은 @MainActor 입니다.
        // 프로퍼티 기본값 자리가 아니라 (MainActor 인) init 안에서 만들어야 안전합니다.
        self.location = LocationService()
        observeIntentEvents()
        reload()
    }

    var isEmpty: Bool { ranked.isEmpty }

    var hasLocationSorting: Bool {
        store.isLocationSortEnabled && location.isAuthorized
    }

    // MARK: - 읽기

    /// 저장소에서 목록을 다시 읽고 정렬합니다.
    func reload() {
        let networks = store.load()
        let sortLocation = store.isLocationSortEnabled ? location.lastLocation : nil
        ranked = NetworkRanker.rank(networks, location: sortLocation, currentSSID: currentSSID)
    }

    /// 앱이 화면에 올라올 때마다 호출합니다.
    /// 현재 SSID 와 위치를 새로 읽고 목록을 재정렬합니다.
    func refreshEverything() async {
        location.requestAuthorization()

        // 현재 SSID — 위치 권한이 있어야 읽힙니다.
        currentSSID = await CurrentNetworkReader.refreshCachedSSID()

        if store.isLocationSortEnabled {
            _ = await location.currentLocation()
        }

        reload()
        consumePendingRequestIfNeeded()
    }

    // MARK: - 연결

    /// 앱 안에서 직접 탭했을 때의 전환. 위젯 경로와 달리 인텐트를 거치지 않습니다.
    func connect(to network: SavedNetwork) async {
        guard connectingID == nil else { return }
        connectingID = network.id
        defer { connectingID = nil }

        do {
            let outcome = try await WiFiConnector.connect(to: network)
            let coordinate = location.lastLocation?.coordinate
            store.recordSuccessfulConnect(
                id: network.id,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude
            )
            currentSSID = store.cachedCurrentSSID
            reload()

            switch outcome {
            case .connected(let ssid):
                banner = Banner(kind: .success, message: "\(ssid) 에 연결했습니다.")
            case .alreadyConnected(let ssid):
                banner = Banner(kind: .info, message: "이미 \(ssid) 에 연결되어 있습니다.")
            case .appliedButUnverified(let ssid):
                banner = Banner(
                    kind: .info,
                    message: "\(ssid) 로 전환을 요청했습니다. 위치 권한이 없어 결과를 확인하지 못했습니다."
                )
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let offersSettings = (error as? WiFiConnectError)?.suggestsOpeningSettings ?? true
            banner = Banner(
                kind: .failure,
                message: message,
                offersSettings: offersSettings && store.opensSettingsOnFailure
            )
        }
    }

    // MARK: - 편집

    /// 좌표는 호출부(편집 화면)가 이미 확정해서 넘깁니다.
    /// 여기서 임의로 채우면 사용자가 "장소 기억"을 끈 것을 되살려 버립니다.
    func save(_ network: SavedNetwork, passphrase: String?) {
        let toSave = network
        store.upsert(toSave)

        if toSave.security.requiresPassphrase {
            do {
                // 비밀번호 칸을 비워 둔 채 저장하면 기존 값을 유지합니다.
                if let passphrase, !passphrase.isEmpty {
                    try KeychainStore.setPassphrase(passphrase, for: toSave.id)
                }
            } catch {
                banner = Banner(kind: .failure, message: error.localizedDescription)
            }
        } else {
            KeychainStore.delete(id: toSave.id)
        }

        reload()
    }

    func delete(_ network: SavedNetwork) {
        store.delete(id: network.id)
        // 이 앱이 등록한 Wi-Fi 설정도 함께 정리합니다.
        WiFiConnector.forget(ssid: network.ssid)
        reload()
    }

    func move(from source: IndexSet, to destination: Int) {
        var networks = ranked.map(\.network)
        networks.move(fromOffsets: source, toOffset: destination)
        store.save(networks)
        reload()
    }

    func hasStoredPassphrase(for network: SavedNetwork) -> Bool {
        KeychainStore.passphrase(for: network.id) != nil
    }

    // MARK: - 위젯에서 들어온 요청

    private func observeIntentEvents() {
        NotificationCenter.default.publisher(for: ConnectEvents.didStart)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.connectingID = notification.userInfo?[ConnectEvents.UserInfoKey.networkID] as? UUID
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: ConnectEvents.didFinish)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                self.connectingID = nil
                let info = notification.userInfo
                let message = info?[ConnectEvents.UserInfoKey.message] as? String ?? ""
                let isFailure = info?[ConnectEvents.UserInfoKey.isFailure] as? Bool ?? false
                let offersSettings = info?[ConnectEvents.UserInfoKey.offersSettings] as? Bool ?? false
                self.currentSSID = self.store.cachedCurrentSSID
                self.banner = Banner(
                    kind: isFailure ? .failure : .success,
                    message: message,
                    offersSettings: isFailure && offersSettings && self.store.opensSettingsOnFailure
                )
                self.reload()
            }
            .store(in: &cancellables)
    }

    /// 위젯 탭으로 앱이 떴지만 인텐트가 아직/이미 끝난 경우를 정리합니다.
    private func consumePendingRequestIfNeeded() {
        guard let pending = PendingConnectRequest.current else { return }
        // 인텐트가 정상 종료되면 스스로 지웁니다. 남아 있으면 중단된 요청이므로 비웁니다.
        if connectingID == nil {
            PendingConnectRequest.clear()
            _ = pending
        }
    }
}
