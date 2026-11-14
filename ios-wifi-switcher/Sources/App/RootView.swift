import SwiftUI

struct RootView: View {

    /// 편집 시트에 넘기는 묶음. QR 로 읽은 비밀번호를 같이 실어 보냅니다.
    struct EditorRequest: Identifiable {
        let id = UUID()
        var network: SavedNetwork
        var initialPassphrase: String?
    }

    @EnvironmentObject private var model: AppModel
    @State private var editorRequest: EditorRequest?
    @State private var isShowingScanner = false
    @State private var isShowingHelp = false
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isEmpty {
                    EmptyStateView(
                        onAdd: { editorRequest = EditorRequest(network: SavedNetwork()) },
                        onScan: { isShowingScanner = true }
                    )
                } else {
                    networkList
                }
            }
            .navigationTitle("Wi-Fi 전환")
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { bannerArea }
        }
        .sheet(item: $editorRequest) { request in
            NetworkEditorView(
                network: request.network,
                initialPassphrase: request.initialPassphrase
            )
            .environmentObject(model)
        }
        .sheet(isPresented: $isShowingScanner) {
            QRScannerSheet { result in
                isShowingScanner = false
                guard let result else { return }
                editorRequest = EditorRequest(
                    network: SavedNetwork(
                        ssid: result.ssid,
                        label: result.ssid,
                        security: result.security,
                        isHidden: result.isHidden
                    ),
                    initialPassphrase: result.passphrase
                )
            }
        }
        .sheet(isPresented: $isShowingHelp) {
            HelpView()
        }
    }

    // MARK: - 목록

    private var networkList: some View {
        List {
            Section {
                ForEach(model.ranked) { item in
                    NetworkRow(
                        item: item,
                        isCurrent: item.network.ssid == model.currentSSID,
                        isConnecting: model.connectingID == item.network.id,
                        showsDistance: model.hasLocationSorting
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await model.connect(to: item.network) }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            model.delete(item.network)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        Button {
                            editorRequest = EditorRequest(network: item.network)
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        .tint(.gray)
                    }
                }
                .onMove { source, destination in
                    model.move(from: source, to: destination)
                }
            } header: {
                headerText
            } footer: {
                Text("한 번 탭하면 바로 전환합니다. 처음 연결하는 네트워크는 iOS 가 확인 창을 한 번 띄웁니다.")
            }
        }
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .refreshable { await model.refreshEverything() }
    }

    private var headerText: some View {
        HStack(spacing: 6) {
            if let ssid = model.currentSSID {
                Image(systemName: "wifi")
                Text("현재: \(ssid)")
            } else {
                Image(systemName: "wifi.slash")
                Text("현재 연결 확인 불가")
            }
            Spacer()
            if model.hasLocationSorting {
                Label("위치순", systemImage: "location.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2)
            }
        }
        .textCase(nil)
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isShowingHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .accessibilityLabel("도움말")
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if !model.isEmpty {
                Button(isEditing ? "완료" : "순서") {
                    isEditing.toggle()
                }
            }
            Menu {
                Button {
                    editorRequest = EditorRequest(network: SavedNetwork())
                } label: {
                    Label("직접 입력", systemImage: "keyboard")
                }
                Button {
                    isShowingScanner = true
                } label: {
                    Label("QR 코드 스캔", systemImage: "qrcode.viewfinder")
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("네트워크 추가")
        }
    }

    // MARK: - 결과 배너

    @ViewBuilder
    private var bannerArea: some View {
        if let banner = model.banner {
            BannerView(banner: banner) {
                model.banner = nil
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - 행

private struct NetworkRow: View {

    let item: NetworkRanker.RankedNetwork
    let isCurrent: Bool
    let isConnecting: Bool
    let showsDistance: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: item.network.tintHex).opacity(0.18))
                Image(systemName: item.network.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: item.network.tintHex))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.network.displayName)
                    .font(.body.weight(.medium))

                HStack(spacing: 6) {
                    if item.network.displayName != item.network.ssid {
                        Text(item.network.ssid)
                    }
                    if showsDistance, let distanceText = item.distanceText {
                        Label(distanceText, systemImage: "location")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isConnecting {
                ProgressView()
            } else if isCurrent {
                Label("연결됨", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
                    .font(.title3)
                    .accessibilityLabel("현재 연결됨")
            } else if item.isNearby {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("근처")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 빈 상태

private struct EmptyStateView: View {

    let onAdd: () -> Void
    let onScan: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "wifi.router")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .padding(.top, 48)

                Text("자주 쓰는 Wi-Fi 를 등록해 주세요")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("""
                    iOS 는 앱이 주변 Wi-Fi 를 스캔하는 것을 허용하지 않습니다.
                    그래서 이 앱은 미리 등록한 네트워크만 다룹니다.
                    한 번 등록해 두면 위젯과 제어 센터에서 한 번의 탭으로 전환할 수 있습니다.
                    """)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    Button(action: onScan) {
                        Label("QR 코드로 등록", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onAdd) {
                        Label("직접 입력", systemImage: "keyboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - 배너

private struct BannerView: View {

    let banner: AppModel.Banner
    let onDismiss: () -> Void

    private var icon: String {
        switch banner.kind {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var tint: Color {
        switch banner.kind {
        case .success: return .green
        case .failure: return .orange
        case .info: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(banner.message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")
            }

            if banner.offersSettings {
                Button {
                    SettingsLauncher.openWiFiSettings()
                    onDismiss()
                } label: {
                    Label("설정에서 Wi-Fi 열기", systemImage: "arrow.up.forward.app")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.35))
        )
    }
}
