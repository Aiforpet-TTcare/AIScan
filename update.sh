#!/bin/bash
set -euo pipefail

# 사용자가 입력한 버전
echo "Enter the new version:"
read NEW_VERSION

PODSPEC="AIScan.podspec"
PREVIOUS_VERSION="$(awk -F '\"' '/spec.version[[:space:]]*=/{ print $2; exit }' "$PODSPEC")"
GUIDE_REPO="${GUIDE_REPO:-kjaylee/com.aiforpet.sdk}"
GUIDE_WORKFLOW="${GUIDE_WORKFLOW:-update-ios-guide.yml}"

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version: $NEW_VERSION (expected x.y.z)"
  exit 1
fi

if [ "$NEW_VERSION" = "$PREVIOUS_VERSION" ]; then
  echo "New version matches the current version: $NEW_VERSION"
  exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "Release must run from main (current: ${CURRENT_BRANCH:-detached})."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Release repository has uncommitted changes. Commit or discard them first."
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$NEW_VERSION" >/dev/null; then
  echo "Tag $NEW_VERSION already exists locally."
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$NEW_VERSION" >/dev/null 2>&1; then
  echo "Tag $NEW_VERSION already exists on origin."
  exit 1
fi

if ! pod trunk me >/dev/null; then
  echo "CocoaPods trunk authentication check failed."
  exit 1
fi

# 바이너리에 같은 버전을 스탬프한 뒤 태그한다 (런타임 telemetry sdk_version ==
# pod/SPM 태그). 이 단계가 없으면 배포 태그만 올라가고 프레임워크 바이너리의
# MARKETING_VERSION 은 그대로라 telemetry 가 어긋난다(이전엔 1.0 으로 고정 유입).
# 형제 AIScan 소스 repo 에서 xcframework 를 재빌드해 이 디렉토리로 출력하고,
# 소스 오브 트루스인 VERSION 파일도 동기화한다.
AISCAN_SRC="${AISCAN_SRC:-../AIScan}"
DISTRIBUTION_ROOT="$(pwd)"
if [ -n "$(git -C "$AISCAN_SRC" status --porcelain)" ]; then
  echo "AIScan source repository has uncommitted changes."
  exit 1
fi

if [ ! -f "$AISCAN_SRC/VERSION" ]; then
  echo "AIScan source VERSION file is missing."
  exit 1
fi
SOURCE_VERSION="$(tr -d '[:space:]' < "$AISCAN_SRC/VERSION")"
if [ "$SOURCE_VERSION" != "$NEW_VERSION" ]; then
  echo "Source VERSION must already be $NEW_VERSION (found: ${SOURCE_VERSION:-empty})."
  echo "Commit the private source version before running the public release."
  exit 1
fi
SOURCE_REVISION="$(git -C "$AISCAN_SRC" rev-parse HEAD)"

echo "Stamping + rebuilding AIScanCore.xcframework at $NEW_VERSION..."
if ! ( cd "$AISCAN_SRC" && GIT_LFS_SKIP_SMUDGE=1 FRAMEWORK_NAME=AIScanCore OUTPUT_DIR="$DISTRIBUTION_ROOT" bash create_xcframework.sh "$NEW_VERSION" ); then
  echo "AIScanCore.xcframework build failed — aborting release."
  exit 1
fi

PROVENANCE_FILE="AIScanCore.source.json"
printf '{\n  "framework": "AIScanCore",\n  "source_version": "%s",\n  "source_revision": "%s",\n  "simulator_architectures": ["arm64"]\n}\n' \
  "$SOURCE_VERSION" "$SOURCE_REVISION" > "$PROVENANCE_FILE"

if ! ( cd "$AISCAN_SRC" && export EXPECTED_SOURCE_REVISION="$SOURCE_REVISION" && export EXPECTED_SOURCE_VERSION="$SOURCE_VERSION" && PUBLIC_ROOT="$DISTRIBUTION_ROOT" bash scripts/audit_public_artifact.sh ); then
  echo "Public artifact audit failed — aborting release."
  exit 1
fi

XCFRAMEWORK="AIScanCore.xcframework"
FRAMEWORK_NAME="${XCFRAMEWORK%.xcframework}"
WARN_BYTES=$((50 * 1024 * 1024))
FAIL_BYTES=$((95 * 1024 * 1024))

format_mib() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f MiB", bytes / 1024 / 1024 }'
}

SIM_BINARY="$(find "$XCFRAMEWORK" -type f -path "*-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" -print -quit)"
if [ -z "$SIM_BINARY" ]; then
  echo "Simulator framework binary was not found in $XCFRAMEWORK."
  exit 1
fi

SIM_ARCHS="$(xcrun lipo -archs "$SIM_BINARY")"
if [ "$SIM_ARCHS" != "arm64" ]; then
  echo "Simulator framework must be arm64-only (found: $SIM_ARCHS)."
  exit 1
fi

echo "Validating XCFramework file sizes..."
while IFS= read -r FILE; do
  FILE_BYTES="$(stat -f%z "$FILE")"
  if [ "$FILE_BYTES" -ge "$FAIL_BYTES" ]; then
    echo "File exceeds the 95 MiB release limit: $FILE ($(format_mib "$FILE_BYTES"))"
    exit 1
  fi
  if [ "$FILE_BYTES" -ge "$WARN_BYTES" ]; then
    echo "Warning: large file will trigger GitHub's 50 MiB warning: $FILE ($(format_mib "$FILE_BYTES"))"
  fi
done < <(find "$XCFRAMEWORK" -type f -print)

CURRENT_TOTAL_BYTES="$(find "$XCFRAMEWORK" -type f -exec stat -f%z {} \; | awk '{ total += $1 } END { print total + 0 }')"
PREVIOUS_TOTAL_BYTES="$(git ls-tree -lr HEAD -- "$XCFRAMEWORK" | awk '{ total += $4 } END { print total + 0 }')"
echo "XCFramework total: $(format_mib "$CURRENT_TOTAL_BYTES") (previous: $(format_mib "$PREVIOUS_TOTAL_BYTES"))"

if [ "$PREVIOUS_TOTAL_BYTES" -gt 0 ] && [ $((CURRENT_TOTAL_BYTES * 100)) -gt $((PREVIOUS_TOTAL_BYTES * 105)) ]; then
  echo "XCFramework grew by more than 5% compared with the currently published artifact."
  exit 1
fi

trigger_guide_update() {
  if [ "${SKIP_GUIDE_UPDATE:-0}" = "1" ]; then
    echo "Skipping guide automation because SKIP_GUIDE_UPDATE=1."
    return
  fi

  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "Warning: GitHub CLI is unavailable or unauthenticated; guide PR was not requested."
    return
  fi

  if gh workflow run "$GUIDE_WORKFLOW" --repo "$GUIDE_REPO" \
    -f version="$NEW_VERSION" \
    -f previous_version="$PREVIOUS_VERSION"; then
    echo "Requested the $NEW_VERSION guide update workflow in $GUIDE_REPO."
  else
    echo "Warning: SDK was published, but the guide update workflow could not be requested."
  fi
}

# Podspec 파일에서 버전 업데이트
echo "Updating version in $PODSPEC to $NEW_VERSION..."
sed -i '' "s/spec.version      = .*/spec.version      = \"$NEW_VERSION\"/" $PODSPEC
sed -i '' "s/:tag => \".*\"/:tag => \"$NEW_VERSION\"/" $PODSPEC

# PACKAGE
PACKAGE="Package.swift"

# PACKAGE 파일 버전 업데이트
echo "Updating version in $PACKAGE to $NEW_VERSION..."
sed -i '' "s/tag: .*/tag: \"$NEW_VERSION\"/" $PACKAGE

# README 설치 스니펫 버전 동기화 (SPM `from:`, CocoaPods `~>`)
README="README.md"
if [ -f "$README" ]; then
  echo "Updating version in $README to $NEW_VERSION..."
  sed -i '' \
    -e "s/from: \"[0-9][0-9.]*\"/from: \"$NEW_VERSION\"/g" \
    -e "s/~> [0-9][0-9.]*/~> $NEW_VERSION/g" \
    "$README"
fi

# 공개 전에 로컬 소스와 생성된 XCFramework 조합을 검증한다. 원격 태그가
# 아직 없어도 검증 가능한 lib lint 를 사용한다.
echo "Linting local $PODSPEC before publishing..."
pod lib lint "$PODSPEC"

# Git 커밋 및 푸시
echo "Committing and pushing changes to git..."
git add "$XCFRAMEWORK" "$PROVENANCE_FILE" "$PODSPEC" "$PACKAGE" README.md
git commit -m "Update podspec version to $NEW_VERSION"

# 태그 추가
git tag "$NEW_VERSION"

# 브랜치와 태그를 함께 푸시해 한쪽만 올라가는 상태를 방지한다.
git push --atomic origin "$CURRENT_BRANCH" "$NEW_VERSION"

# Podspec 검증
echo "Linting $PODSPEC from the published tag..."
pod spec lint "$PODSPEC"

echo "Lint successful, pushing to trunk..."
pod trunk push "$PODSPEC"
echo "Successfully pushed $PODSPEC to CocoaPods trunk."

trigger_guide_update
