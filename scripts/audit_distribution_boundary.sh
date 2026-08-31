#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/AIScanCore.xcframework"
EXPECTED_SYMBOLS="$ROOT/scripts/aiscancore-public-symbols.txt"

if [[ ! -d "$CORE" ]]; then
  echo "AIScanCore.xcframework is missing." >&2
  exit 1
fi

if [[ ! -f "$EXPECTED_SYMBOLS" ]]; then
  echo "Core public symbol allowlist is missing." >&2
  exit 1
fi

for pattern in '*.swiftmodule' '*.swiftinterface' '*.private.swiftinterface'; do
  if find "$CORE" -name "$pattern" -print -quit | grep -q .; then
    echo "Core must expose Objective-C ABI only; found $pattern." >&2
    exit 1
  fi
done

for forbidden in \
  TensorFlowLite OnnxRuntime rawPrediction pred_values modelPath modelKey \
  access_token clientKeySecret attestationObject AppAttest DeviceCheck \
  DCAppAttestService attestation_failed \
  TTTelemetry TTTelemetryEvent TelemetryEvent AISCFlowVault \
  AISCNetworkTelemetry sendTelemetry flushTelemetry telemetry-event-catalog; do
  if grep -R -n -F "$forbidden" "$ROOT/Sources" >/dev/null; then
    echo "Forbidden Core implementation symbol in public UI: $forbidden" >&2
    exit 1
  fi
done

# The private implementation must also remain opaque after compilation. ObjC
# runtime names and wire literals are easy to recover from an XCFramework even
# when the source target is not distributed, so audit both device and simulator
# binaries rather than relying on source visibility alone.
for core_binary in "$CORE"/*/AIScanCore.framework/AIScanCore; do
  if nm -gjU "$core_binary" | grep -E \
      'AISCFlowVault|AISCNetworkTelemetry|TTTelemetry|TelemetryEvent' >/dev/null; then
    echo "Logging implementation symbol leaked from Core binary: $core_binary" >&2
    exit 1
  fi

  for forbidden_binary_log in \
    'event_type' \
    'session_id' \
    'shot_seq' \
    '/events' \
    'album_opened' \
    'album_canceled' \
    'result_viewed' \
    'result_shared'; do
    if strings "$core_binary" | grep -F "$forbidden_binary_log" >/dev/null; then
      echo "Logging wire literal leaked from Core binary: $forbidden_binary_log" >&2
      exit 1
    fi
  done

  for forbidden_runtime_name in \
    AISCDisplayAssetTransport \
    AISCNetworkProgressTransport \
    AISCNetworkTTAPIOperation; do
    if strings "$core_binary" | grep -F "$forbidden_runtime_name" >/dev/null; then
      echo "Internal runtime class leaked from Core binary: $forbidden_runtime_name" >&2
      exit 1
    fi
  done

  for architecture in $(lipo -archs "$core_binary"); do
    actual_symbols="$(mktemp "$ROOT/tmp/aiscancore-symbols.XXXXXX")"
    trap 'rm -f "$actual_symbols"' EXIT
    nm -arch "$architecture" -gjU "$core_binary" | LC_ALL=C sort -u > "$actual_symbols"
    if ! LC_ALL=C diff -u "$EXPECTED_SYMBOLS" "$actual_symbols"; then
      echo "Unexpected Core ABI export for $architecture: $core_binary" >&2
      exit 1
    fi
    rm -f "$actual_symbols"
    trap - EXIT
  done
done

CAMERA_CONTROLLER="$ROOT/Sources/AIScanCameraUI/AIScanCameraController.swift"
for forbidden_workflow_call in \
  AISCSession coreSession frameInput evaluateFrame captureFrame diagnoseImage AISCImageInput; do
  if grep -n -F "$forbidden_workflow_call" "$CAMERA_CONTROLLER" >/dev/null; then
    echo "Protected scan workflow leaked into public camera UI: $forbidden_workflow_call" >&2
    exit 1
  fi
done

# Camera implementation is private Core know-how. Public Swift may display the
# Core-owned session in AVCaptureVideoPreviewLayer, but must never construct or
# configure camera capture plumbing itself.
for forbidden_camera_implementation in \
  'AVCaptureSession()' \
  AVCaptureDeviceInput \
  AVCaptureVideoDataOutput \
  setSampleBufferDelegate \
  AVCaptureVideoDataOutputSampleBufferDelegate \
  cameraDeviceForPosition \
  cameraDeviceForDeviceType \
  applyCameraSessionPolicy \
  applyCameraDevicePolicy \
  consumeSampleBuffer; do
  if grep -n -F "$forbidden_camera_implementation" "$CAMERA_CONTROLLER" >/dev/null; then
    echo "Private camera implementation leaked into public camera UI: $forbidden_camera_implementation" >&2
    exit 1
  fi
done
if ! grep -q -F "AISCCameraEngineControlling" "$CAMERA_CONTROLLER"; then
  echo "Public camera UI must depend on the narrow Core engine boundary." >&2
  exit 1
fi

# Public Swift can forward display-safe callbacks, but it must not own any
# network transport. Telemetry and display-asset delivery are entirely owned
# by the private Objective-C Core binary.
for forbidden_ui_transport in URLSession URLRequest dataTask uploadTask; do
  if grep -R -n -F "$forbidden_ui_transport" "$ROOT/Sources" \
      --exclude='AIScanLegacyCameraGuide.swift' >/dev/null; then
    echo "Network transport leaked into public UI: $forbidden_ui_transport" >&2
    exit 1
  fi
done

# The original camera guide is a display-only WebView exception. Its top-level
# navigation is constrained to the exact HTTPS CDN host and known guide paths,
# and it must not persist website data or own general-purpose transport.
GUIDE_WEBVIEW="$ROOT/Sources/AIScanCameraUI/Legacy/AIScanLegacyCameraGuide.swift"
for required_guide_control in \
  'resource-core.aiforpetcdn.com' \
  'AIScanCameraGuideNavigationPolicy.allows' \
  'websiteDataStore = .nonPersistent()' \
  'javaScriptCanOpenWindowsAutomatically = false'; do
  if ! grep -n -F "$required_guide_control" "$GUIDE_WEBVIEW" >/dev/null; then
    echo "Camera guide WebView control is missing: $required_guide_control" >&2
    exit 1
  fi
done
for forbidden_guide_transport in URLSession dataTask uploadTask http://; do
  if grep -n -F "$forbidden_guide_transport" "$GUIDE_WEBVIEW" >/dev/null; then
    echo "General transport leaked into camera guide: $forbidden_guide_transport" >&2
    exit 1
  fi
done

# Logging and telemetry delivery are Core responsibilities. Keep even local
# console logging out of distributable UI source so host applications cannot
# accidentally expose SDK diagnostics in their unified logs.
for forbidden_ui_log in \
  'telemetry' \
  'TTTelemetry' \
  'TelemetryEvent' \
  'analysisTracker' \
  'trackEvent(' \
  'trackScreen(' \
  'Mixpanel' \
  'event_type' \
  'app_report' \
  'session_id' \
  'shot_seq' \
  '/events' \
  'Logger(' \
  'os_log(' \
  'NSLog(' \
  'print('; do
  if grep -R -n -F "$forbidden_ui_log" "$ROOT/Sources" >/dev/null; then
    echo "Logging implementation leaked into public UI: $forbidden_ui_log" >&2
    exit 1
  fi
done

if [[ -d "$ROOT/AIScan.xcframework" ]]; then
  echo "Legacy Swift AIScan.xcframework must not be distributed." >&2
  exit 1
fi

echo "Core/UI distribution boundary audit passed."
