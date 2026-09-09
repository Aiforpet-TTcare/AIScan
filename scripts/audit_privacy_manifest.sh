#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI_MANIFEST="$ROOT/Sources/AIScanCameraUI/PrivacyInfo.xcprivacy"
DEVICE_MANIFEST="$ROOT/AIScanCore.xcframework/ios-arm64/AIScanCore.framework/PrivacyInfo.xcprivacy"
SIMULATOR_MANIFEST="$ROOT/AIScanCore.xcframework/ios-arm64_x86_64-simulator/AIScanCore.framework/PrivacyInfo.xcprivacy"

for manifest in "$UI_MANIFEST" "$DEVICE_MANIFEST" "$SIMULATOR_MANIFEST"; do
  if [[ ! -f "$manifest" ]]; then
    echo "Privacy manifest is missing: $manifest" >&2
    exit 1
  fi
  plutil -lint "$manifest" >/dev/null
  if grep -A1 -F '<key>NSPrivacyTracking</key>' "$manifest" | grep -F '<true/>' >/dev/null; then
    echo "AIScan must not declare tracking: $manifest" >&2
    exit 1
  fi
done

if ! cmp -s "$DEVICE_MANIFEST" "$SIMULATOR_MANIFEST"; then
  echo "Core privacy manifests differ between XCFramework slices." >&2
  exit 1
fi

for required_ui_value in \
  NSPrivacyAccessedAPICategorySystemBootTime \
  35F9.1 \
  NSPrivacyAccessedAPICategoryUserDefaults \
  CA92.1; do
  if ! grep -F "$required_ui_value" "$UI_MANIFEST" >/dev/null; then
    echo "UI privacy declaration is missing: $required_ui_value" >&2
    exit 1
  fi
done

for required_core_value in \
  NSPrivacyCollectedDataTypePhotosorVideos \
  NSPrivacyCollectedDataTypeUserID \
  NSPrivacyCollectedDataTypeOtherUserContent \
  NSPrivacyCollectedDataTypePurposeAppFunctionality; do
  if ! grep -F "$required_core_value" "$DEVICE_MANIFEST" >/dev/null; then
    echo "Core privacy declaration is missing: $required_core_value" >&2
    exit 1
  fi
done

if ! grep -F '.process("PrivacyInfo.xcprivacy")' "$ROOT/Package.swift" >/dev/null; then
  echo "SwiftPM does not package the UI privacy manifest." >&2
  exit 1
fi
if ! grep -F "Sources/AIScanCameraUI/PrivacyInfo.xcprivacy" "$ROOT/AIScan.podspec" >/dev/null; then
  echo "CocoaPods does not package the UI privacy manifest." >&2
  exit 1
fi

echo "Privacy manifest audit passed."
