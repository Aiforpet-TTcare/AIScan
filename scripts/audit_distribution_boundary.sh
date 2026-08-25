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

if [[ -d "$ROOT/AIScan.xcframework" ]]; then
  echo "Legacy Swift AIScan.xcframework must not be distributed." >&2
  exit 1
fi

echo "Core/UI distribution boundary audit passed."
