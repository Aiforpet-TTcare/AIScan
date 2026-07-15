#!/bin/bash
set -euo pipefail

# 사용자가 입력한 버전
echo "Enter the new version:"
read NEW_VERSION

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version: $NEW_VERSION (expected x.y.z)"
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
if [ -n "$(git -C "$AISCAN_SRC" status --porcelain)" ]; then
  echo "AIScan source repository has uncommitted changes."
  exit 1
fi

echo "Stamping + rebuilding AIScan.xcframework at $NEW_VERSION..."
echo "$NEW_VERSION" > "$AISCAN_SRC/VERSION"
if ! ( cd "$AISCAN_SRC" && GIT_LFS_SKIP_SMUDGE=1 bash create_xcframework.sh "$NEW_VERSION" ); then
  echo "xcframework build failed — aborting release."
  exit 1
fi

# Podspec 파일 이름
PODSPEC="AIScan.podspec"

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
git add AIScan.xcframework "$PODSPEC" "$PACKAGE" README.md
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
