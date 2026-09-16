#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
OUTPUT="${2:-$ROOT/tmp/public-release-$VERSION}"
SOURCE_REF="${PUBLIC_SOURCE_REF:-HEAD}"

# Keep a caller-supplied relative path anchored to the invocation directory.
# The script later changes into the staging tree; leaving OUTPUT relative there
# would nest DerivedData inside a second copy of the requested path.
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$PWD/$OUTPUT"
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: scripts/stage_public_release.sh x.y.z [new-output-directory]" >&2
  exit 1
fi
if [[ -e "$OUTPUT" ]]; then
  echo "Output already exists; choose a new path: $OUTPUT" >&2
  exit 1
fi
if ! git -C "$ROOT" rev-parse --verify "$SOURCE_REF^{commit}" >/dev/null; then
  echo "Unknown source revision: $SOURCE_REF" >&2
  exit 1
fi

public_paths=(
  .gitignore
  Package.swift
  AIScan.podspec
  README.md
  RELEASE.md
  SECURE_SPLIT_MIGRATION.md
  ARCHITECTURE.md
  Gemfile
  Gemfile.lock
  AIScanCore.xcframework
  Sources
  Tests/AIScanCompatibilityTests/AIScanDisplayAssetBoundaryTests.swift
  Tests/AIScanCompatibilityTests/AIScanFivePartVisualMatrixTests.swift
  Tests/AIScanCompatibilityTests/AIScanResultOriginalVisualParityTests.swift
  Tests/AIScanCompatibilityTests/AIScanSupportedSurfaceTests.swift
  Tests/AIScanCompatibilityTests/AIScanVisualRegressionSupport.swift
  Tests/AIScanCompatibilityTests/AIScanLifecyclePerformanceTests.swift
  Tests/AIScanCompatibilityTests/AIScanCameraGuidanceParityTests.swift
  Tests/AIScanCompatibilityTests/AIScanCameraUIStateTests.swift
  Tests/AIScanCompatibilityTests/AIScanPDFReportTests.swift
  Tests/AIScanCompatibilityTests/AIScanLocalizationParityTests.swift
  scripts/aiscancore-public-symbols.txt
  scripts/audit_distribution_boundary.sh
  scripts/audit_ios13_compatibility.sh
  scripts/audit_original_ui_fidelity.sh
  scripts/audit_privacy_manifest.sh
  scripts/audit_core_public_headers.sh
  scripts/audit_publishable_keys.sh
  scripts/audit_public_release_tree.sh
  scripts/audit_ui_resources.sh
  scripts/create_ios13_compatibility_host.rb
  scripts/pdf-resource-sha256.txt
  scripts/resolve_ios_simulator_destination.sh
  scripts/stage_public_release.sh
)

mkdir -p "$OUTPUT"
git -C "$ROOT" archive --format=tar "$SOURCE_REF" "${public_paths[@]}" \
  | tar -xf - -C "$OUTPUT"
mkdir -p "$OUTPUT/tmp"

sed -i '' "s/spec.version      = .*/spec.version      = \"$VERSION\"/" \
  "$OUTPUT/AIScan.podspec"
sed -i '' "s/:tag => \".*\"/:tag => \"$VERSION\"/" \
  "$OUTPUT/AIScan.podspec"
sed -i '' "s/tag: .*/tag: \"$VERSION\"/" "$OUTPUT/Package.swift"
sed -i '' \
  -e "s/from: \"[0-9][0-9.]*\"/from: \"$VERSION\"/g" \
  -e "s/~> [0-9][0-9.]*/~> $VERSION/g" \
  "$OUTPUT/README.md"

"$OUTPUT/scripts/audit_public_release_tree.sh"
"$OUTPUT/scripts/audit_ios13_compatibility.sh"
(
  cd "$OUTPUT"
  SIMULATOR_DESTINATION="$(scripts/resolve_ios_simulator_destination.sh)"
  xcodebuild test -scheme AIScan \
    -destination "$SIMULATOR_DESTINATION" \
    -derivedDataPath "$OUTPUT/tmp/public-release-derived-data" \
    -quiet \
    -resultBundlePath "$OUTPUT/tmp/public-release-tests.xcresult"
)

git -C "$OUTPUT" init -b main >/dev/null
git -C "$OUTPUT" add .
git -C "$OUTPUT" \
  -c user.name="AIScan Release Automation" \
  -c user.email="sdk-release@aiforpet.com" \
  commit -m "release: AIScan $VERSION" >/dev/null
git -C "$OUTPUT" tag "$VERSION"

if command -v gitleaks >/dev/null; then
  gitleaks git "$OUTPUT" --redact --no-banner
else
  echo "gitleaks is required to approve the clean public history." >&2
  exit 1
fi

echo "Validated clean public release $VERSION at $OUTPUT"
echo "Nothing was pushed. Review this one-commit repository before adding a public remote."
