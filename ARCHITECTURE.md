# AIScan Core/UI 분리 불변 원칙

분리 기준은 비공개 저장소 `feat/ttapi-contract-result`의 TTAPI 구성 버전이다.
분리는 기능이나 디자인을 바꾸는 작업이 아니라 빌드·보안·배포 경계를 바꾸는
작업이다. 아래 네 조건 중 하나라도 깨지면 릴리즈할 수 없다.

## 1. 기능 동일

- eye/skin/teeth 입력 context와 촬영 흐름
- 진행률과 퍼센트 애니메이션
- timeout, retry, error 처리
- 일반 결과와 `contract_result` callback 횟수·시점
- 삼성화재 `contract_result.payload` 무가공 전달

위 동작은 기준 버전과 동등해야 한다.

## 2. 디자인 동일

- 원본 `TTCamera`, `TTEtc`, `TTPopup` Storyboard와 asset을 사용한다.
- 새 화면으로 다시 그리거나 간소화하지 않는다.
- `scripts/audit_original_ui_fidelity.sh`가 Storyboard와 asset tree 해시를
  검사한다.
- SwiftPM class lookup에 필요한 비시각 module metadata 제거 외의 Storyboard
  XML 변경은 허용하지 않는다.

## 3. 보안 철저

| 배포 단위 | 공개 여부 | 책임 |
|---|---|---|
| `AIScanCore.xcframework` | 구현 비공개, 승인된 Objective-C header만 공개 | publishable-key auth, manifest, 모델/추론, 전처리, TTAPI transport와 실행 정책 |
| `AIScanCameraUI` | 공개 Swift 소스 | 원본 카메라·가이드·진행률·재촬영 UI와 Core DTO 표시 |
| `AIScan` | 공개 Swift 소스 | 앱용 facade와 승인된 결과 계약 전달 |

공개 UI에는 토큰/서명 검증, 모델 이름·경로·복호화, threshold, raw
prediction/tensor, 비공개 endpoint 조립을 넣지 않는다. UI가 받는 값은
`AISCScanContext`, `AISCFrameEvaluation`, `AISCDisplayResult`,
`AISCContractResult.payload` 같은 승인된 DTO뿐이다.

## 4. Xcode/Swift 호환성 결합 제거

Core 바이너리는 Objective-C ABI만 노출하고 Swift module/interface를 포함하지
않는다. Core를 빌드한 Swift 컴파일러 버전이 고객 앱에 전파되지 않는다. 공개
UI는 소스로 배포되어 고객 앱의 Swift 컴파일러로 빌드된다.

지원 Xcode 하한은 릴리즈 매트릭스로 검증하지만 Core와 UI를 같은 Xcode에서
동시에 재빌드해야 하는 결합은 두지 않는다.

## 버전 규칙

- UI-only patch: Core public header와 `AIScanCore.source.json` 변경 금지
- Core-compatible patch/minor: 공개 Objective-C header 변경 금지
- Core API 변경: 명시적으로 승인한 major release에서만 허용
- 태그는 해당 시점의 UI 소스, Core 바이너리, provenance를 함께 고정
