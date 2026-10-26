#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for binary in "$ROOT"/AIScanCore.xcframework/*/AIScanCore.framework/AIScanCore; do
  if [[ ! -f "$binary" ]]; then
    echo "Core binary is missing" >&2
    exit 1
  fi
  # These are implementation/runtime fingerprints, not public compatibility DTOs.
  # Keep this check on each distributed slice so a stale binary cannot restore
  # local clinical inference while the public Swift facade looks server-only.
  if strings "$binary" | grep -Ei \
    'onnxruntime|OrtGetApiBase|AISCDiagnosisBackendRun|^AISCZ8$|^AISCV8$|^toBGR$' >/dev/null; then
    echo "Local clinical analysis remains in $binary" >&2
    exit 1
  fi
done
echo "Server-only Core binary audit passed."
