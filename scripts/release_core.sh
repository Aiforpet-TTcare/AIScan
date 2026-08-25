#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
PRIVATE_ROOT="${2:-}"
ACTION="${3:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! -d "$PRIVATE_ROOT" ]]; then
  echo "Usage: scripts/release_core.sh x.y.z /absolute/private/AIScan [--publish]" >&2
  exit 1
fi
if [[ -n "$ACTION" && "$ACTION" != "--publish" ]]; then
  echo "Unknown option: $ACTION" >&2
  exit 1
fi
PRIVATE_ROOT="$(cd "$PRIVATE_ROOT" && pwd)"
if [[ -n "$(git -C "$PRIVATE_ROOT" status --porcelain)" ]]; then
  echo "Private Core repository must be clean." >&2
  exit 1
fi
SOURCE_VERSION="$(tr -d '[:space:]' < "$PRIVATE_ROOT/VERSION")"
if [[ "$SOURCE_VERSION" != "$VERSION" ]]; then
  echo "Private VERSION must be $VERSION (found: $SOURCE_VERSION)." >&2
  exit 1
fi

STAGE="$ROOT/tmp/core-release-$VERSION"
if [[ "$STAGE" != "$ROOT"/tmp/core-release-* ]]; then
  echo "Unsafe staging path: $STAGE" >&2
  exit 1
fi
rm -rf "$STAGE"
mkdir -p "$STAGE"
trap 'rm -rf "$STAGE"' EXIT

SOURCE_REVISION="$(git -C "$PRIVATE_ROOT" rev-parse HEAD)"
(
  cd "$PRIVATE_ROOT"
  GIT_LFS_SKIP_SMUDGE=1 \
  FRAMEWORK_NAME=AIScanCore \
  OUTPUT_DIR="$STAGE" \
  bash create_xcframework.sh "$VERSION"
)
printf '{\n  "framework": "AIScanCore",\n  "source_version": "%s",\n  "source_revision": "%s",\n  "simulator_architectures": ["arm64", "x86_64"]\n}\n' \
  "$VERSION" "$SOURCE_REVISION" > "$STAGE/AIScanCore.source.json"

(
  cd "$PRIVATE_ROOT"
  EXPECTED_SOURCE_REVISION="$SOURCE_REVISION" \
  EXPECTED_SOURCE_VERSION="$VERSION" \
  PUBLIC_ROOT="$STAGE" \
  bash scripts/audit_public_artifact.sh
)

rsync -a --delete "$STAGE/AIScanCore.xcframework/" "$ROOT/AIScanCore.xcframework/"
cp "$STAGE/AIScanCore.source.json" "$ROOT/AIScanCore.source.json"

# The simulator directory name includes its architecture set, so adding x86_64
# legitimately renames that slice. Compare the stable device headers against the
# released API, then separately require every packaged slice to expose the same
# headers.
DEVICE_HEADERS="AIScanCore.xcframework/ios-arm64/AIScanCore.framework/Headers"
SIMULATOR_HEADERS="AIScanCore.xcframework/ios-arm64_x86_64-simulator/AIScanCore.framework/Headers"
if [[ "${ALLOW_CORE_API_CHANGE:-0}" != "1" ]] && \
   ! git diff --quiet -- "$DEVICE_HEADERS"; then
  echo "Public Core headers changed. Use an approved major release or restore the ABI." >&2
  exit 1
fi
if ! diff -rq "$DEVICE_HEADERS" "$SIMULATOR_HEADERS" >/dev/null; then
  echo "Device and simulator Core headers differ." >&2
  exit 1
fi

git add AIScanCore.xcframework AIScanCore.source.json
if [[ "$ACTION" != "--publish" ]]; then
  git reset AIScanCore.xcframework AIScanCore.source.json
  echo "Validated Core release $VERSION; artifacts were updated locally but nothing was committed or published."
  exit 0
fi

git commit -m "release(core): AIScanCore $VERSION"

scripts/release_ui.sh "$VERSION" --publish
