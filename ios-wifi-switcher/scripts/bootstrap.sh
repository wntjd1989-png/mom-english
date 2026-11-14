#!/usr/bin/env bash
# Xcode 프로젝트를 생성하고 엽니다. macOS 에서 실행하세요.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen 이 없습니다. 먼저 설치해 주세요:"
  echo "  brew install xcodegen"
  echo
  echo "Homebrew 가 없으면: https://brew.sh 의 설치 명령을 먼저 실행하세요."
  exit 1
fi

CURRENT_ID="$(sed -n 's/.*static let bundleRoot = "\(.*\)".*/\1/p' Sources/Shared/AppGroup.swift)"
if [[ "$CURRENT_ID" == "com.example.wifiswitcher" ]]; then
  echo "⚠️  번들 ID 가 아직 예시값(com.example.wifiswitcher)입니다."
  echo "    실기기에 설치하려면 본인 것으로 바꿔야 합니다:"
  echo "      ./scripts/set-bundle-id.sh com.본인이름.wifiswitcher"
  echo
  read -r -p "그래도 계속할까요? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || exit 1
fi

echo "프로젝트 생성 중..."
xcodegen generate

echo "완료: WiFiSwitcher.xcodeproj"
if command -v open >/dev/null 2>&1; then
  open WiFiSwitcher.xcodeproj
fi
