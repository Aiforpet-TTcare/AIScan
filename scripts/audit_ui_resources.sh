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

placeholder="$CATALOG/legacy/checkResultEyeImgNo.imageset/checkResultEyeImgNo.pdf"
placeholder_hash="$(shasum -a 256 "$placeholder" | awk '{print $1}')"
if [[ "$placeholder_hash" != "6eb90948484c66cdc9f2006c69e6bcc5a4f1c91385c4f1da1804e07a4fc8c5f9" ]]; then
  echo "Result placeholder no longer matches the original host artwork." >&2
  exit 1
fi

if ! shasum -a 256 -c "$ROOT/scripts/pdf-resource-sha256.txt" >/dev/null; then
  echo "PDF resources no longer match the reviewed original report assets." >&2
  exit 1
fi

echo "AIScanCameraUI storyboard/XIB resource audit passed."
