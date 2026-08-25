#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCE_ROOT="$ROOT/Sources/AIScanCameraUI/ReferenceResources"
CATALOG="$RESOURCE_ROOT/Assets/AIScan.xcassets"

missing="$({
  rg --no-filename -o 'image="[^"]+"' "$RESOURCE_ROOT" \
    --glob '*.storyboard' --glob '*.xib' \
    | sed -E 's/image="([^"]+)"/\1/' \
    | sort -u
} | comm -23 - <({
  find "$CATALOG" -type d \( -name '*.imageset' -o -name '*.symbolset' \) \
    | sed -E 's#.*/([^/]+)\.(imageset|symbolset)#\1#' \
    | sort -u
}))"

if [[ -n "$missing" ]]; then
  echo "Storyboard/XIB image references missing from AIScanCameraUI resources:" >&2
  echo "$missing" >&2
  exit 1
fi

echo "AIScanCameraUI storyboard/XIB resource audit passed."
