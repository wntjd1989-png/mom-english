import CoreLocation
import SwiftUI

/// 네트워크 등록 / 편집 화면.
struct NetworkEditorView: View {

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SavedNetwork
    @State private var passphrase: String
    @State private var remembersLocation: Bool
    @State private var hadStoredPassphrase = false
    @State private var isSaving = false

    private let isNew: Bool

    init(network: SavedNetwork, initialPassphrase: String? = nil) {
        self._draft = State(initialValue: network)
        self._passphrase = State(initialValue: initialPassphrase ?? "")
        self._remembersLocation = State(initialValue: network.hasCoordinate)
        self.isNew = network.ssid.isEmpty && network.connectCount == 0
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                securitySection
                appearanceSection
                locationSection
                if !isNew { dangerSection }
            }
            .navigationTitle(isNew ? "Wi-Fi 추가" : "Wi-Fi 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                hadStoredPassphrase = model.hasStoredPassphrase(for: draft)
            }
        }
    }

    // MARK: - 섹션

    private var identitySection: some View {
        Section {
            TextField("Wi-Fi 이름 (SSID)", text: $draft.ssid)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("별칭 (예: 집, 회사)", text: $draft.label)
        } header: {
            Text("네트워크")
        } footer: {
            Text("SSID 는 대소문자와 띄어쓰기까지 정확히 일치해야 연결됩니다. 설정 > Wi-Fi 에 보이는 이름을 그대로 입력하세요.")
        }
    }

    private var securitySection: some View {
        Section {
            Picker("보안 방식", selection: $draft.security) {
                ForEach(WiFiSecurity.allCases) { security in
                    Text(security.displayName).tag(security)
                }
            }

            if draft.security.requiresPassphrase {
                SecureField(
                    hadStoredPassphrase ? "비밀번호 (변경할 때만 입력)" : "비밀번호",
                    text: $passphrase
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            Toggle("숨겨진 네트워크", isOn: $draft.isHidden)
        } header: {
            Text("보안")
        } footer: {
            if draft.security.requiresPassphrase {
                Text("비밀번호는 키체인에만 저장되며 백업이나 로그에 평문으로 남지 않습니다. WPA 는 8~63자, WEP 는 5자 또는 13자여야 합니다.")
            } else {
                Text("카페·공항처럼 로그인 페이지가 뜨는 네트워크는 연결은 되지만 인터넷 사용 전에 Safari 에서 한 번 로그인해야 합니다.")
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            LabeledContent("아이콘") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(NetworkPalette.symbols, id: \.self) { symbol in
                            Button {
                                draft.symbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(draft.symbol == symbol
                                                  ? Color(hex: draft.tintHex).opacity(0.25)
                                                  : Color.secondary.opacity(0.12))
                                    )
                                    .foregroundStyle(draft.symbol == symbol
                                                     ? Color(hex: draft.tintHex)
                                                     : Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            LabeledContent("색상") {
                HStack(spacing: 10) {
                    ForEach(NetworkPalette.hexes, id: \.self) { hex in
                        Button {
                            draft.tintHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.primary, lineWidth: draft.tintHex == hex ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("위젯 표시")
        } footer: {
            Text("여기서 고른 아이콘과 색이 홈 화면 위젯과 제어 센터 버튼에 그대로 쓰입니다.")
        }
    }

    private var locationSection: some View {
        Section {
            Toggle("이 장소를 기억하기", isOn: $remembersLocation)
                .disabled(!model.location.isAuthorized && !draft.hasCoordinate)

            if draft.hasCoordinate {
                LabeledContent("저장된 좌표") {
                    Text(coordinateText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("위치")
        } footer: {
            if model.location.isAuthorized {
                Text("현재 위치를 기억해 두면, 그 장소에 있을 때 이 네트워크가 목록 맨 위로 올라옵니다. iOS 가 주변 Wi-Fi 스캔을 막아 두었기 때문에 '신호 세기' 대신 쓰는 방식입니다.")
            } else {
                Text("위치 권한이 없어 장소를 기억할 수 없습니다. 설정에서 위치 접근을 '앱을 사용하는 동안'으로 허용해 주세요.")
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                model.delete(draft)
                dismiss()
            } label: {
                Label("이 네트워크 삭제", systemImage: "trash")
            }
        } footer: {
            Text("삭제하면 저장된 비밀번호와 iOS 에 등록된 Wi-Fi 설정도 함께 지워집니다.")
        }
    }

    // MARK: - 로직

    private var coordinateText: String {
        guard let latitude = draft.latitude, let longitude = draft.longitude else { return "-" }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }

    private var canSave: Bool {
        guard draft.isComplete else { return false }
        guard draft.security.requiresPassphrase else { return true }
        // 새로 만들 때는 비밀번호가 반드시 필요합니다.
        // 기존 항목이면 키체인에 이미 값이 있으므로 비워 둬도 됩니다.
        return hadStoredPassphrase || !passphrase.isEmpty
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var toSave = draft
        toSave.ssid = toSave.ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        toSave.label = toSave.label.trimmingCharacters(in: .whitespacesAndNewlines)

        if remembersLocation {
            // 아직 좌표가 없으면 지금 위치를 한 번 받아 채웁니다.
            // 측위에 실패하면 좌표 없이 저장하고, 다음 연결 성공 시 다시 시도합니다.
            if !toSave.hasCoordinate,
               let coordinate = await model.location.currentLocation()?.coordinate {
                toSave.latitude = coordinate.latitude
                toSave.longitude = coordinate.longitude
            }
        } else {
            toSave.latitude = nil
            toSave.longitude = nil
        }

        model.save(toSave, passphrase: passphrase.isEmpty ? nil : passphrase)
        dismiss()
    }
}
