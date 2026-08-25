#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
ACTION="${2:-}"
BUNDLE_BIN="${BUNDLE_BIN:-bundle}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: scripts/release_ui.sh x.y.z [--publish]" >&2
  exit 1
fi
if [[ -n "$ACTION" && "$ACTION" != "--publish" ]]; then
  echo "Unknown option: $ACTION" >&2
  exit 1
fi

BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "main" && "${ALLOW_RELEASE_BRANCH:-0}" != "1" ]]; then
  echo "Release must run from main (current: ${BRANCH:-detached})." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain -- . ':!.build' ':!tmp')" ]]; then
  echo "Commit source changes before release." >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
  echo "Tag already exists: $VERSION" >&2
  exit 1
fi

PREVIOUS_VERSION="$(awk -F '"' '/spec.version[[:space:]]*=/{ print $2; exit }' AIScan.podspec)"
CORE_BEFORE="$(git hash-object AIScanCore.source.json)"

scripts/audit_original_ui_fidelity.sh
scripts/audit_distribution_boundary.sh
xcodebuild -scheme AIScanCameraUI \
  -destination 'generic/platform=iOS Simulator' build -quiet
xcodebuild test -scheme AIScan-Package \
  -destination "${IOS_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 15 Pro,OS=latest}" \
  -quiet

if [[ "${SKIP_POD_LINT:-0}" != "1" ]]; then
  "$BUNDLE_BIN" check
  "$BUNDLE_BIN" exec pod lib lint AIScan.podspec --allow-warnings
fi

if [[ "$(git hash-object AIScanCore.source.json)" != "$CORE_BEFORE" ]]; then
  echo "UI-only release changed Core provenance." >&2
  exit 1
fi

sed -i '' "s/spec.version      = .*/spec.version      = \"$VERSION\"/" AIScan.podspec
sed -i '' "s/:tag => \".*\"/:tag => \"$VERSION\"/" AIScan.podspec
sed -i '' "s/tag: .*/tag: \"$VERSION\"/" Package.swift
sed -i '' \
  -e "s/from: \"[0-9][0-9.]*\"/from: \"$VERSION\"/g" \
  -e "s/~> [0-9][0-9.]*/~> $VERSION/g" \
  README.md

if [[ "$ACTION" != "--publish" ]]; then
  echo "Validated UI release $PREVIOUS_VERSION -> $VERSION; nothing was published."
  exit 0
fi

git add AIScan.podspec Package.swift README.md
git commit -m "release: AIScan $VERSION"
git tag "$VERSION"
git push --atomic origin "$BRANCH" "$VERSION"

if [[ "${SKIP_POD_PUBLISH:-0}" != "1" ]]; then
  "$BUNDLE_BIN" exec pod spec lint AIScan.podspec --allow-warnings
  "$BUNDLE_BIN" exec pod trunk push AIScan.podspec --allow-warnings
fi

echo "Published AIScan $VERSION (UI-only; Core unchanged)."
