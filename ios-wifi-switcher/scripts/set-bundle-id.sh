#!/usr/bin/env bash
# 번들 ID 를 한 번에 바꿉니다.
#
# 번들 ID 는 네 곳에 흩어져 있고, 하나라도 어긋나면 위젯이 네트워크 목록을
# 읽지 못합니다(App Group 불일치). 이 스크립트가 네 곳을 동시에 고칩니다.
#
#   사용법:  ./scripts/set-bundle-id.sh com.myname.wifiswitcher
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "사용법: $0 <새 번들 ID>"
  echo "예:     $0 com.myname.wifiswitcher"
  exit 1
fi

NEW_ID="$1"

if [[ ! "$NEW_ID" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]; then
  echo "오류: 번들 ID 형식이 올바르지 않습니다: $NEW_ID"
  echo "      영문/숫자/하이픈과 점으로만 구성해야 합니다. 예: com.myname.wifiswitcher"
  exit 1
fi

cd "$(dirname "$0")/.."

# 현재 값을 AppGroup.swift 에서 읽어 옵니다(단일 진실 공급원).
OLD_ID="$(sed -n 's/.*static let bundleRoot = "\(.*\)".*/\1/p' Sources/Shared/AppGroup.swift)"

if [[ -z "$OLD_ID" ]]; then
  echo "오류: Sources/Shared/AppGroup.swift 에서 현재 번들 ID 를 찾지 못했습니다."
  exit 1
fi

if [[ "$OLD_ID" == "$NEW_ID" ]]; then
  echo "이미 $NEW_ID 입니다. 변경할 것이 없습니다."
  exit 0
fi

echo "번들 ID 변경: $OLD_ID  →  $NEW_ID"

FILES=(
  Sources/Shared/AppGroup.swift
  project.yml
  Resources/App/WiFiSwitcher.entitlements
  Resources/Controls/WiFiControls.entitlements
)

for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "  경고: $file 없음, 건너뜀"
    continue
  fi
  # BSD(macOS) sed 와 GNU sed 양쪽에서 동작하도록 백업 확장자를 명시합니다.
  sed -i.bak "s|${OLD_ID}|${NEW_ID}|g" "$file"
  rm -f "${file}.bak"
  echo "  수정: $file"
done

echo
echo "완료. 이제 다음을 실행하세요:"
echo "  xcodegen generate && open WiFiSwitcher.xcodeproj"
echo
echo "Xcode 에서 확인할 것:"
echo "  - 두 타깃(WiFiSwitcher, WiFiControls) 모두 Signing & Capabilities 에서 팀 선택"
echo "  - 두 타깃 모두 App Group 이 group.${NEW_ID} 로 체크되어 있는지"
