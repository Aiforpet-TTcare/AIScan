#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORYBOARD_ROOT="$ROOT/Sources/AIScanCameraUI/ReferenceResources/Legacy"
ASSET_ROOT="$ROOT/Sources/AIScanCameraUI/ReferenceResources/Assets/AIScan.xcassets"

check_storyboard() {
  local name="$1"
  local expected="$2"
  local actual
  actual="$(shasum -a 256 "$STORYBOARD_ROOT/$name" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "$name no longer matches the original AIScan 2.2.4 design source." >&2
    exit 1
  fi
}

check_storyboard \
  "TTCamera.storyboard" \
  "79e586386008ff827dc7d18cda00501efe7466bfb00fba32160a54267cfc92d3"
check_storyboard \
  "TTEtc.storyboard" \
  "cccac5d98f24c30cb8098856750bce8538e366de804925512c764ad583e2a71f"
check_storyboard \
  "TTPopup.storyboard" \
  "704a065e994460ceeeea7c1a11c2961d30ca1488732373f3c15dbccdae8e264b"

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
