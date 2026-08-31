#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_ROOT="$ROOT/Sources/AIScanCameraUI/ReferenceResources/Assets/AIScan.xcassets"

canonical_layout_hash() {
  sed -E \
    -e 's/ customModule="[^"]+" customModuleProvider="[^"]+"//g' \
    -e 's/customClass="AIScanResultSpaceCell"/customClass="SpaceCell"/g' \
    -e 's/customClass="AIScan([^"]+)"/customClass="\1"/g' \
    -e 's/<arscnView /<view /g' \
    -e 's#</arscnView>#</view>#g' \
    "$1" | shasum -a 256 | awk '{print $1}'
}

check_layout() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(canonical_layout_hash "$ROOT/Sources/AIScanCameraUI/ReferenceResources/$path")"
  if [ "$actual" != "$expected" ]; then
    echo "$path no longer matches the original AIScan 2.2.4 layout source." >&2
    exit 1
  fi
}

check_layout \
  "Legacy/TTCamera.storyboard" \
  "5f67511ef02372078116f2c4f313b1c72bcf0526abf5c68e966d57f5b835f2e0"
check_layout \
  "Legacy/TTEtc.storyboard" \
  "cccac5d98f24c30cb8098856750bce8538e366de804925512c764ad583e2a71f"
check_layout \
  "Legacy/TTPopup.storyboard" \
  "704a065e994460ceeeea7c1a11c2961d30ca1488732373f3c15dbccdae8e264b"
check_layout "Result/Result.storyboard" \
  "63fb826e9bdd080a53a5bea3e603e84c614075282de66c9a5b9d55d538cdb589"
check_layout "Result/ResultDateCell.xib" \
  "565cc546fc196c7b5291c5b1619c04579f0a10cc2160a32838d43f1d36ff610e"
check_layout "Result/ResultItemCell.xib" \
  "99ff00ae51da940d99d2c7963be2c5c7d30b8e03e7d722e195b1e9d47215e003"
check_layout "Result/ResultNoticeCell.xib" \
  "723f1425a70997076e4db9142b7548cb08ae7a6b1d5fba25e06dd1dc8518cfa0"
check_layout "Result/ResultStatusCell.xib" \
  "86e0cc3bbded48cff0c630f1c5d40a4afd4cff17aba5f8ab9d3dfb6a63d2b647"
check_layout "Result/ResultTabCell.xib" \
  "9574c1622f1ebf9a0ffa84cbd719deb239c7ee664a51352148d8cd6f3b6fbc40"
check_layout "Result/ResultTitleCell.xib" \
  "67cc6c6c9d8bbb603483f69cf9f8f745238db963b9a4f06ad864175944e2d7b2"
check_layout "Result/SpaceCell.xib" \
  "00575e45a4a0db7be1fb483b97302cdc105d262528802bf1c0cee21ca3620c00"

asset_hash="$({
  cd "$ASSET_ROOT"
  # The legacy/ group contains original host-owned images that were missing
  # from the first public split. Their completeness and runtime loading are
  # audited separately; keep this hash pinned to the original SDK catalog.
  find . -type f ! -name .DS_Store ! -path './legacy/*' -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256
} | shasum -a 256 | awk '{print $1}')"

if [ "$asset_hash" != "ae32d261a8fa355e1089d1634b7ad903d05bef5be272e8764487c473418531af" ]; then
  echo "AIScan asset catalog no longer matches the original design source." >&2
  exit 1
fi

echo "Original AIScan 2.2.4 UI fidelity audit passed."
