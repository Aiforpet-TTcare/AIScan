#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORYBOARD_ROOT="$ROOT/Sources/AIScanCameraUI/ReferenceResources/Legacy"
ASSET_ROOT="$ROOT/Sources/AIScanCameraUI/ReferenceResources/Assets/AIScan.xcassets"

check_storyboard() {
  local name="$1"
  local expected="$2"
  local actual
  actual="$({
    sed 's/customModule="AIScanCameraUI"/customModule="AIScan"/g' \
      "$STORYBOARD_ROOT/$name"
  } | shasum -a 256 | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "$name no longer matches the original AIScan 2.2.4 design source." >&2
    exit 1
  fi
}

check_storyboard \
  "TTCamera.storyboard" \
  "1d23cb498b804eb1f62d4ddcebe5d09ef6ec41fa50930c9e54b0ddc3d9ead19a"
check_storyboard \
  "TTEtc.storyboard" \
  "dca17cca862a85f69b8773aca34c349a0eea1511dfef94f3c4b73d234b33e88c"
check_storyboard \
  "TTPopup.storyboard" \
  "6a8107b29d90a614d07a64f02736b66c7c476a26e86bee3a09bfd28b86224180"

asset_hash="$({
  cd "$ASSET_ROOT"
  find . -type f ! -name .DS_Store -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256
} | shasum -a 256 | awk '{print $1}')"

if [ "$asset_hash" != "ae32d261a8fa355e1089d1634b7ad903d05bef5be272e8764487c473418531af" ]; then
  echo "AIScan asset catalog no longer matches the original design source." >&2
  exit 1
fi

echo "Original AIScan 2.2.4 UI fidelity audit passed."
