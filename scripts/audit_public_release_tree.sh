#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for forbidden_path in \
  "$ROOT/Examples" \
  "$ROOT/.build" \
  "$ROOT/.swiftpm" \
  "$ROOT/.serena" \
  "$ROOT/AIScanCore.source.json" \
  "$ROOT/AIScanUI.source.json" \
  "$ROOT/docs/2026-08-26-ios-gap-zero-handoff.md" \
  "$ROOT/scripts/run_samsung_e2e_bridge.sh" \
  "$ROOT/Tests/AIScanCompatibilityTests/AIScanAlbumEndToEndTests.swift" \
  "$ROOT/Tests/AIScanCompatibilityTests/AIScanCompatibilityTests.swift"; do
  if [[ -e "$forbidden_path" ]]; then
    echo "Private QA path leaked into public release: $forbidden_path" >&2
    exit 1
  fi
done

text_roots=(
  "$ROOT/Package.swift"
  "$ROOT/AIScan.podspec"
  "$ROOT/README.md"
  "$ROOT/RELEASE.md"
  "$ROOT/SECURE_SPLIT_MIGRATION.md"
  "$ROOT/ARCHITECTURE.md"
  "$ROOT/Sources"
  "$ROOT/Tests"
)

if grep -R -I -n -E '/Users/|/Volumes/|github\.com/kjaylee' \
    "${text_roots[@]}" >/dev/null; then
  echo "Developer path or private repository URL leaked into public release." >&2
  exit 1
fi

for forbidden_text in \
  Samsung samsung_fire samsung-fire \
  SecureSplitValidationHost AISCAN_E2E_SECRET \
  run_samsung_e2e_bridge ios-gap-zero-handoff \
  ttcare_primary feat/ttapi-contract-result; do
  if grep -R -n -i -F "$forbidden_text" "${text_roots[@]}" >/dev/null; then
    echo "Customer or private QA detail leaked into public release: $forbidden_text" >&2
    exit 1
  fi
done

for core_binary in "$ROOT"/AIScanCore.xcframework/*/AIScanCore.framework/AIScanCore; do
  for forbidden_binary_text in \
    'Samsung Fire' samsung_fire samsung-fire samsungfire samsung-user \
    AISCDisplayAssetTransport AISCNetworkProgressTransport \
    AISCNetworkTTAPIOperation; do
    if strings "$core_binary" | grep -i -F "$forbidden_binary_text" >/dev/null; then
      echo "Private detail leaked into Core binary: $forbidden_binary_text" >&2
      exit 1
    fi
  done
done

"$ROOT/scripts/audit_original_ui_fidelity.sh"
"$ROOT/scripts/audit_ui_resources.sh"
"$ROOT/scripts/audit_distribution_boundary.sh"
"$ROOT/scripts/audit_publishable_keys.sh"
"$ROOT/scripts/audit_privacy_manifest.sh"
"$ROOT/scripts/audit_core_public_headers.sh"

echo "Public release tree audit passed."
