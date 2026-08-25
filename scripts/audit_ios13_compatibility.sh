#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXPECTED_MIN_OS="13.0"
CORE="$ROOT/AIScanCore.xcframework"
DEVICE_BINARY="$CORE/ios-arm64/AIScanCore.framework/AIScanCore"
SIMULATOR_BINARY="$CORE/ios-arm64_x86_64-simulator/AIScanCore.framework/AIScanCore"
DERIVED_DATA="$ROOT/tmp/ios13-compatibility-derived-data"

if ! grep -Fq '.iOS(.v13)' Package.swift || \
   ! grep -Fq 'spec.platform     = :ios, "13.0"' AIScan.podspec; then
  echo "SwiftPM and CocoaPods must both declare iOS 13.0." >&2
  exit 1
fi

if [[ ! -f "$DEVICE_BINARY" || ! -f "$SIMULATOR_BINARY" ]]; then
  echo "AIScanCore must contain an iOS device slice and a universal simulator slice." >&2
  exit 1
fi

device_min_os="$(xcrun vtool -show-build "$DEVICE_BINARY" | awk '$1 == "minos" { print $2; exit }')"
simulator_x86_min_os="$(xcrun vtool -show-build -arch x86_64 "$SIMULATOR_BINARY" | awk '$1 == "minos" { print $2; exit }')"
simulator_arm_min_os="$(xcrun vtool -show-build -arch arm64 "$SIMULATOR_BINARY" | awk '$1 == "minos" { print $2; exit }')"

if [[ "$device_min_os" != "$EXPECTED_MIN_OS" || "$simulator_x86_min_os" != "$EXPECTED_MIN_OS" ]]; then
  echo "Core iOS 13 regression: device=$device_min_os simulator-x86_64=$simulator_x86_min_os" >&2
  exit 1
fi
if [[ "$simulator_arm_min_os" != "$EXPECTED_MIN_OS" && "$simulator_arm_min_os" != "14.0" ]]; then
  echo "Unexpected arm64 simulator minimum: $simulator_arm_min_os" >&2
  exit 1
fi

for binary in "$DEVICE_BINARY" "$SIMULATOR_BINARY"; do
  if otool -L "$binary" | grep -Eq '/AVFAudio\.framework/|TensorFlowLite|onnxruntime|libswift_Concurrency'; then
    echo "Core reintroduced a forbidden legacy runtime dependency: $binary" >&2
    otool -L "$binary" >&2
    exit 1
  fi
done

if [[ "$DERIVED_DATA" != "$ROOT"/tmp/ios13-compatibility-* ]]; then
  echo "Unsafe derived-data path: $DERIVED_DATA" >&2
  exit 1
fi
rm -rf "$DERIVED_DATA"
trap 'rm -rf "$DERIVED_DATA"' EXIT

TMPDIR="$ROOT/tmp" xcodebuild -quiet \
  -project Examples/SecureSplitValidationHost/SecureSplitValidationHost.xcodeproj \
  -scheme SecureSplitValidationHost \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  IPHONEOS_DEPLOYMENT_TARGET="$EXPECTED_MIN_OS" \
  build

APP="$DERIVED_DATA/Build/Products/Release-iphoneos/SecureSplitValidationHost.app"
APP_BINARY="$APP/SecureSplitValidationHost"
app_min_os="$(xcrun vtool -show-build "$APP_BINARY" | awk '$1 == "minos" { print $2; exit }')"
if [[ "$app_min_os" != "$EXPECTED_MIN_OS" ]]; then
  echo "Validation host minimum is $app_min_os, expected $EXPECTED_MIN_OS." >&2
  exit 1
fi
if ! otool -L "$APP_BINARY" | grep -Fq '@rpath/libswift_Concurrency.dylib'; then
  echo "Validation host did not link the Swift concurrency back-deployment runtime." >&2
  exit 1
fi
if [[ ! -f "$APP/Frameworks/libswift_Concurrency.dylib" ]]; then
  echo "Validation host did not embed libswift_Concurrency.dylib for iOS 13." >&2
  exit 1
fi

echo "iOS 13 compatibility audit passed (device 13, x86_64 simulator 13, Swift concurrency embedded)."
