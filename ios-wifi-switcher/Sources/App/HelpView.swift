import SwiftUI

/// iOS 제약과 사용법을 솔직하게 설명하는 화면.
/// "왜 주변 Wi-Fi 목록이 안 보이나?" 라는 질문이 반드시 나오기 때문에 앱 안에 넣어 둡니다.
struct HelpView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var opensSettingsOnFailure = NetworkStore.shared.opensSettingsOnFailure
    @State private var locationSortEnabled = NetworkStore.shared.isLocationSortEnabled

    var body: some View {
        NavigationStack {
            List {
                limitationSection
                howToSection
                settingsSection
                diagnosticsSection
            }
            .navigationTitle("도움말")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var limitationSection: some View {
        Section {
            Row(
                icon: "eye.slash",
                tint: .orange,
                title: "주변 Wi-Fi 목록은 볼 수 없습니다",
                detail: "iOS 는 서드파티 앱의 Wi-Fi 스캔을 차단합니다. 스캔에 필요한 NEHotspotHelper 권한은 Apple 이 통신사·ISP 급 사업자에게만 승인합니다. 그래서 이 앱은 미리 등록해 둔 네트워크만 다룹니다."
            )
            Row(
                icon: "hand.tap",
                tint: .blue,
                title: "전환은 앱이 열린 동안 처리됩니다",
                detail: "iOS 는 앱이 화면에 떠 있을 때만 Wi-Fi 전환을 허용합니다. 그래서 위젯을 탭하면 앱이 잠깐 열리고 전환이 끝납니다. 더 짧은 경로는 iOS 에 존재하지 않습니다."
            )
            Row(
                icon: "power",
                tint: .gray,
                title: "Wi-Fi 자체를 켜고 끌 수는 없습니다",
                detail: "앱에서 Wi-Fi 전원을 토글하는 API 는 공개되어 있지 않습니다. 제어 센터의 Wi-Fi 버튼을 써 주세요."
            )
        } header: {
            Text("iOS 제약")
        }
    }

    private var howToSection: some View {
        Section {
            Row(
                icon: "1.circle.fill",
                tint: .accentColor,
                title: "네트워크 등록",
                detail: "+ 버튼으로 SSID 와 비밀번호를 넣습니다. 공유기에 Wi-Fi QR 코드가 있으면 스캔이 훨씬 빠릅니다."
            )
            Row(
                icon: "2.circle.fill",
                tint: .accentColor,
                title: "홈 화면 위젯 추가",
                detail: "바탕화면을 길게 눌러 편집 모드 → 좌측 상단 + → 'Wi-Fi 전환' 검색 → 크기를 골라 추가합니다. 중간/큰 크기는 여러 네트워크가 격자로 보입니다."
            )
            Row(
                icon: "3.circle.fill",
                tint: .accentColor,
                title: "제어 센터 / 잠금화면 버튼 추가",
                detail: "제어 센터를 내린 뒤 좌측 상단 + → '컨트롤 추가' → 'Wi-Fi 전환' 선택 → 버튼을 탭해 연결할 네트워크를 고릅니다. 같은 컨트롤을 잠금화면이나 액션 버튼에도 배치할 수 있습니다."
            )
            Row(
                icon: "exclamationmark.bubble",
                tint: .orange,
                title: "처음 연결할 때 뜨는 확인 창",
                detail: "iOS 가 네트워크마다 한 번 '연결하겠습니까?' 를 묻습니다. 한 번 '연결' 을 누르면 이후에는 묻지 않습니다."
            )
        } header: {
            Text("사용법")
        }
    }

    private var settingsSection: some View {
        Section {
            Toggle("전환 실패 시 설정 앱 열기", isOn: $opensSettingsOnFailure)
                .onChange(of: opensSettingsOnFailure) { _, newValue in
                    NetworkStore.shared.opensSettingsOnFailure = newValue
                }

            Toggle("위치 기반 자동 정렬", isOn: $locationSortEnabled)
                .onChange(of: locationSortEnabled) { _, newValue in
                    NetworkStore.shared.isLocationSortEnabled = newValue
                }
        } header: {
            Text("설정")
        } footer: {
            Text("위치 기반 정렬을 켜면, 네트워크를 등록한 장소에 가까울수록 목록 위로 올라옵니다. 주변 스캔 대신 쓰는 대안입니다.")
        }
    }

    private var diagnosticsSection: some View {
        Section {
            LabeledContent("App Group 공유") {
                Text(AppGroup.isSharedDefaultsAvailable ? "정상" : "설정 안 됨")
                    .foregroundStyle(AppGroup.isSharedDefaultsAvailable ? .green : .red)
            }
            LabeledContent("App Group ID") {
                Text(AppGroup.identifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("진단")
        } footer: {
            if AppGroup.isSharedDefaultsAvailable {
                Text("앱과 위젯이 같은 저장소를 쓰고 있습니다.")
            } else {
                Text("App Group 이 설정되지 않아 위젯이 네트워크 목록을 읽을 수 없습니다. Xcode 의 Signing & Capabilities 에서 앱 타깃과 위젯 타깃 양쪽에 같은 App Group 을 추가해 주세요.")
            }
        }
    }
}

private struct Row: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
