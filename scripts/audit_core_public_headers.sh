#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_HEADER="$ROOT/AIScanCore.xcframework/ios-arm64/AIScanCore.framework/Headers/AISCConfiguration.h"
SIMULATOR_HEADER="$ROOT/AIScanCore.xcframework/ios-arm64_x86_64-simulator/AIScanCore.framework/Headers/AISCConfiguration.h"

if ! cmp -s "$DEVICE_HEADER" "$SIMULATOR_HEADER"; then
  echo "Core configuration headers differ between XCFramework slices." >&2
  exit 1
fi

for required_surface in publishableKey environment initWithPublishableKey; do
  if ! grep -F "$required_surface" "$DEVICE_HEADER" >/dev/null; then
    echo "Core configuration header is missing supported surface: $required_surface" >&2
    exit 1
  fi
done

for forbidden_surface in \
  bundleIdentifierOverride \
  appVersionOverride \
  teamIdentifierOverride \
  resourceDirectoryURL \
  requestTimeout \
  diagnosisTimeout \
  diagnosisPollInterval \
  callbackQueue; do
  if grep -F "$forbidden_surface" "$DEVICE_HEADER" >/dev/null; then
    echo "Internal Core configuration leaked into the public header: $forbidden_surface" >&2
    exit 1
  fi
  if grep -F "$forbidden_surface" "$ROOT/Sources/AIScan/AIScanManager.swift" >/dev/null; then
    echo "Public facade depends on internal Core configuration: $forbidden_surface" >&2
    exit 1
  fi
done

echo "Core public-header audit passed."
