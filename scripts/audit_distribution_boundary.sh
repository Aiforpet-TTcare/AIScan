#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/AIScanCore.xcframework"

if [[ ! -d "$CORE" ]]; then
  echo "AIScanCore.xcframework is missing." >&2
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
  access_token clientKeySecret attestationObject AppAttest; do
  if grep -R -n -F "$forbidden" "$ROOT/Sources" >/dev/null; then
    echo "Forbidden Core implementation symbol in public UI: $forbidden" >&2
    exit 1
  fi
done

CAMERA_CONTROLLER="$ROOT/Sources/AIScanCameraUI/AIScanCameraController.swift"
for forbidden_workflow_call in \
  AISCSession coreSession frameInput evaluateFrame captureFrame diagnoseImage AISCImageInput; do
  if grep -n -F "$forbidden_workflow_call" "$CAMERA_CONTROLLER" >/dev/null; then
    echo "Protected scan workflow leaked into public camera UI: $forbidden_workflow_call" >&2
    exit 1
  fi
done
if ! grep -q -F "AISCCameraEngineControlling" "$CAMERA_CONTROLLER"; then
  echo "Public camera UI must depend on the narrow Core engine boundary." >&2
  exit 1
fi

if [[ -d "$ROOT/AIScan.xcframework" ]]; then
  echo "Legacy Swift AIScan.xcframework must not be distributed." >&2
  exit 1
fi

echo "Core/UI distribution boundary audit passed."
