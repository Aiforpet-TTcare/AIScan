# AIScan 빠른 배포

관리 목적의 별도 승인 단계 대신 네 개의 자동 게이트만 사용한다.

1. 기능 parity와 원본 UI 해시
2. Core/UI 보안 경계
3. iOS 13 host·Swift concurrency back-deployment와 SwiftPM build/test
4. release commit/tag atomic push

## UI-only 배포 — 기본 경로

Core를 재빌드하지 않는다. 공개 Swift UI, 원본 Storyboard/assets, 문서 수정은
이 경로로 하루 여러 번 배포할 수 있다.

```bash
scripts/release_ui.sh 3.0.1 --publish
```

`--publish`를 빼면 검증과 버전 metadata 준비까지만 한다.
Ruby 도구 버전 차이로 lint 결과가 달라지지 않도록 `Gemfile`의 CocoaPods와
Xcodeproj 버전을 고정하지만, CocoaPods는 레거시 호환 채널이며 기본 배포를
차단하지 않는다. 기존 Pod 고객에게도 배포할 때만 아래처럼 별도로 검증·게시한다.

```bash
VALIDATE_COCOAPODS=1 PUBLISH_COCOAPODS=1 \
  scripts/release_ui.sh 3.0.1 --publish
```

## Core 포함 배포

auth, manifest, 모델/추론, 전처리, TTAPI transport가 변경됐을 때만 사용한다.
Core는 먼저 공개 저장소의 `tmp/`에 빌드·검증되므로 실패한 빌드가 현재 배포
바이너리를 덮어쓰지 않는다.

```bash
ALLOW_CORE_API_CHANGE=1 scripts/release_core.sh 3.0.0 /absolute/path/to/private/AIScan --publish
```

patch/minor에서 공개 Objective-C header 변경은 자동 차단한다. 승인된 major
변경만 `ALLOW_CORE_API_CHANGE=1`로 진행한다.

## 롤백

기존 태그를 삭제하거나 재사용하지 않는다. 문제 release commit을 revert한 뒤
새 patch 버전으로 UI-only 배포한다.

```bash
git revert <release-commit>
scripts/release_ui.sh 3.0.1 --publish
```

이전 태그가 UI 소스, Core 바이너리, provenance를 함께 보존하므로 별도 수동
백업 파일 없이 같은 조합으로 복구할 수 있다.
