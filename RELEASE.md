# AIScan 빠른 배포

공개 저장소의 기존 이력을 그대로 푸시하지 않는다. 공개 후보는 private staging
commit에서 승인된 파일만 골라 새 Git 이력 한 개로 생성한다.

## UI-only 또는 Core 포함 후보 생성

Core 변경이 있으면 먼저 검증된 XCFramework와 provenance를 staging commit에
반영한다. 그 다음 UI-only/Core 포함 여부와 관계없이 동일한 명령을 사용한다.

```bash
scripts/stage_public_release.sh 3.0.4
```

이 명령은 다음을 자동 검증한다.

1. 원본 Storyboard·asset·언어 리소스 fidelity
2. Core/UI 경계와 architecture별 38개 공개 ABI allowlist
3. iOS 13 device·simulator 하한과 Swift runtime 결합 제거
4. 공개 가능한 XCTest 전체
5. 고객사명·내부 QA host·bridge·handoff 문서 부재
6. 새 단일-commit Git history의 secret scan

검증에 성공하면 `tmp/public-release-<version>`에 로컬 Git 저장소와 같은 이름의
tag가 생긴다. 어떤 원격에도 자동으로 push하지 않는다. 승인 후 이 clean 저장소에만
공개 remote를 추가하고 `main`과 tag를 atomic push한다.

## 빠른 롤백

기존 태그를 삭제하거나 재사용하지 않는다. 직전 공개 태그의 clean tree에서 문제
commit을 되돌린 뒤 새 patch 버전으로 후보를 다시 생성한다. 태그가 UI 소스, Core
바이너리, provenance를 한 조합으로 보존하므로 별도 수동 백업 파일은 필요 없다.
