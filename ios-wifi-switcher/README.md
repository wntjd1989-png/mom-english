# Wi-Fi 전환 (iOS)

저장해 둔 Wi-Fi 를 **홈 화면 위젯**과 **제어 센터 / 잠금화면 컨트롤**에서
**탭 한 번으로** 전환하는 iPhone 앱입니다.

---

## ⚠️ 먼저 읽어 주세요 — iOS 가 막아 둔 것

이 앱을 만들기 전에 반드시 알아야 할 제약입니다. **앱의 품질 문제가 아니라
iOS 자체의 정책**입니다.

| 하고 싶은 것 | 가능? | 이유 |
|---|:---:|---|
| 주변에 신호가 잡히는 Wi-Fi 목록 보기 | ❌ | 스캔에는 `NEHotspotHelper` 엔타이틀먼트가 필요하고, Apple 은 이를 통신사·ISP 급 사업자에게만 승인합니다. 개인/일반 앱은 신청해도 거부됩니다. |
| 특정 Wi-Fi 로 전환 | ✅ | `NEHotspotConfiguration` 으로 가능. **단 SSID 와 비밀번호를 앱이 미리 알고 있어야** 합니다. |
| 현재 연결된 Wi-Fi 이름 읽기 | ✅ | `Access WiFi Information` 권한 + 위치 권한이 모두 있어야 합니다. |
| Wi-Fi 전원 자체를 켜고 끄기 | ❌ | 공개 API 가 없습니다. 제어 센터의 Wi-Fi 버튼을 쓰세요. |
| 위젯 탭 → 앱 안 뜨고 바로 전환 | ❌ | iOS 는 **앱이 포그라운드일 때만** Wi-Fi 전환을 허용합니다 (`applicationIsNotInForeground`). |

### 그래서 이 앱이 택한 방식

- **"신호가 잡히는 목록"의 대안** → 사용자가 등록한 네트워크를 **위치 기반으로 자동 정렬**합니다.
  각 네트워크를 등록/연결한 장소의 좌표를 기억해 두고, 지금 있는 곳에서 가까운 것을 위로 올립니다.
  실제 체감은 "집에 오면 집 Wi-Fi 가 맨 위, 회사 가면 회사 Wi-Fi 가 맨 위"입니다.
- **"원터치 전환"의 현실** → 위젯/컨트롤을 탭하면 **앱이 잠깐 떴다가 전환이 끝납니다.**
  탭 횟수는 1회 그대로이고, iOS 에서 이보다 짧은 경로는 존재하지 않습니다.
- 각 네트워크를 **처음** 연결할 때 iOS 가 "연결하겠습니까?" 확인 창을 한 번 띄웁니다.
  한 번 허용하면 그 다음부터는 묻지 않습니다.

---

## 구성

```
ios-wifi-switcher/
├── project.yml                  XcodeGen 설정 (프로젝트 파일을 여기서 생성)
├── scripts/
│   ├── bootstrap.sh             프로젝트 생성 + Xcode 열기
│   └── set-bundle-id.sh         번들 ID 를 네 파일에 일괄 반영
├── Sources/
│   ├── Shared/                  앱 + 위젯이 함께 쓰는 코어
│   │   ├── AppGroup.swift              공유 식별자 (번들 ID 단일 진실 공급원)
│   │   ├── SavedNetwork.swift          저장 모델
│   │   ├── NetworkStore.swift          App Group UserDefaults 저장소
│   │   ├── KeychainStore.swift         비밀번호 (키체인)
│   │   ├── WiFiConnector.swift         실제 Wi-Fi 전환 + 오류 해석
│   │   ├── CurrentNetworkReader.swift  현재 SSID 읽기
│   │   ├── NetworkRanker.swift         위치 기반 정렬
│   │   ├── WiFiQRParser.swift          Wi-Fi QR 코드 해석
│   │   ├── NetworkEntity.swift         컨트롤 설정용 AppEntity
│   │   ├── ConnectToNetworkIntent.swift 위젯/컨트롤이 실행하는 인텐트
│   │   └── ColorHex.swift              색/아이콘 팔레트
│   ├── App/                     앱 본체 (SwiftUI)
│   │   ├── WiFiSwitcherApp.swift
│   │   ├── AppModel.swift
│   │   ├── RootView.swift              목록 + 결과 배너
│   │   ├── NetworkEditorView.swift     등록/편집
│   │   ├── QRScannerView.swift         QR 스캔 (AVFoundation)
│   │   ├── HelpView.swift              제약 설명 + 설정 + 진단
│   │   ├── LocationService.swift
│   │   └── SettingsLauncher.swift      실패 시 설정 앱 열기
│   └── Controls/                위젯 + 컨트롤 확장
│       ├── WiFiControlsBundle.swift
│       ├── WiFiListWidget.swift        홈 화면 위젯 (소/중/대)
│       └── QuickConnectControl.swift   제어 센터 컨트롤 (iOS 18+)
└── Resources/                   Info.plist, entitlements, 에셋
```

---

## 기능

- **등록된 Wi-Fi 목록** — 별칭·아이콘·색을 지정해서 한눈에 구분
- **탭 한 번 전환** — 앱 목록 / 홈 화면 위젯 / 제어 센터 / 잠금화면 / 액션 버튼
- **현재 연결된 Wi-Fi 표시** — 목록과 위젯 상단에 표시 (위치 권한 필요)
- **위치 기반 자동 정렬** — 지금 있는 장소에서 가까운 네트워크를 위로
- **QR 코드 등록** — 공유기에 붙은 Wi-Fi QR 을 스캔해 SSID·비밀번호 자동 입력
- **전환 실패 시 설정 앱 열기** — 실패 배너에서 바로 설정 > Wi-Fi 로 이동
- **비밀번호는 키체인에만** — `UserDefaults`·백업·로그에 평문으로 남지 않음
- 홈 화면 위젯 크기별 표시 개수: 소 2개 / 중 4개 / 대 8개

### 요구 사항

- iPhone, **iOS 17.0 이상** (제어 센터 컨트롤은 iOS 18.0 이상)
- Mac + Xcode 16 이상
- **Apple Developer Program (유료, $99/년)** — 아래 설명 참고

> **무료 개발자 계정으로도 되나요?**
> 빌드 자체는 됩니다. 하지만 핵심 권한인 **Hotspot Configuration** 은 무료
> 개인 팀에서 제공되지 않을 가능성이 높습니다. 그 경우 앱은 실행되지만
> Wi-Fi 전환 시 오류가 납니다. 또 무료 계정은 7일마다 재설치가 필요합니다.

---

## 빌드 방법

자세한 단계는 **[SETUP.md](SETUP.md)** 에 있습니다. 요약하면:

```bash
brew install xcodegen                                   # 한 번만
./scripts/set-bundle-id.sh com.본인이름.wifiswitcher      # 번들 ID 교체
./scripts/bootstrap.sh                                  # 프로젝트 생성 + Xcode 열기
```

그다음 Xcode 에서 **두 타깃 모두**(WiFiSwitcher, WiFiControls):
1. Signing & Capabilities → 본인 Team 선택
2. App Group `group.com.본인이름.wifiswitcher` 체크
3. 앱 타깃에만 **Hotspot Configuration**, **Access WiFi Information** 추가

---

## 아직 검증되지 않은 부분

이 코드는 **리눅스 환경에서 작성되어 실제 컴파일·기기 테스트를 거치지 않았습니다.**
순수 로직(Wi-Fi QR 파서)은 별도 검증했지만, 다음은 Xcode 에서 처음 빌드할 때
조정이 필요할 수 있습니다.

- `ControlWidgetButton` 라벨 구성 — iOS 18 SDK 버전에 따라 시그니처가 다를 수 있음
- Swift 6 언어 모드로 올릴 경우의 동시성 경고 (현재 `SWIFT_STRICT_CONCURRENCY: minimal`)
- `App-Prefs:root=WIFI` 딥링크 — 비공개 스킴이라 iOS 버전에 따라 무시될 수 있음
  (실패 시 앱 설정 화면으로 폴백하도록 구현되어 있음)

빌드 오류가 나면 메시지를 그대로 알려 주세요.
