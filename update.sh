#!/bin/bash

# 사용자가 입력한 버전
echo "Enter the new version:"
read NEW_VERSION

# 바이너리에 같은 버전을 스탬프한 뒤 태그한다 (런타임 telemetry sdk_version ==
# pod/SPM 태그). 이 단계가 없으면 배포 태그만 올라가고 프레임워크 바이너리의
# MARKETING_VERSION 은 그대로라 telemetry 가 어긋난다(이전엔 1.0 으로 고정 유입).
# 형제 AIScan 소스 repo 에서 xcframework 를 재빌드해 이 디렉토리로 출력하고,
# 소스 오브 트루스인 VERSION 파일도 동기화한다.
AISCAN_SRC="${AISCAN_SRC:-../AIScan}"
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

# Git 커밋 및 푸시
echo "Committing and pushing changes to git..."
git add .
git commit -m "Update podspec version to $NEW_VERSION"

# 현재 브랜치 이름 가져오기
CURRENT_BRANCH=$(git branch --show-current)

# 브랜치가 없을 경우 'main'으로 설정
if [ -z "$CURRENT_BRANCH" ]; then
  CURRENT_BRANCH="main"
  git branch -M main
fi

# 태그 추가
git tag $NEW_VERSION

# 원격에 푸시
git push origin $CURRENT_BRANCH
git push origin $NEW_VERSION

# Podspec 검증
echo "Linting $PODSPEC..."
pod spec lint $PODSPEC

# 검증 성공 여부 확인
if [ $? -eq 0 ]; then
  echo "Lint successful, pushing to trunk..."
  pod trunk push $PODSPEC
  if [ $? -eq 0 ]; then
    echo "Successfully pushed $PODSPEC to CocoaPods trunk."
  else
    echo "Failed to push $PODSPEC to CocoaPods trunk."
    exit 1
  fi
else
  echo "Lint failed for $PODSPEC. Please fix the errors and try again."
  exit 1
fi
