# AIScan

**한국어** · [English](README.md)

AIScan은 iOS에서 반려견의 눈·치아·피부와 반려묘의 눈·치아를 검사하는 SDK입니다.
검사 대상과 사진 품질은 기기에서 확인하고 분석은 서버에서 실행합니다.

## 설치

아래 버전은 3.3.0 공개 태그가 생성된 후 사용하세요. Swift Package Manager는
iOS 13 이상, CocoaPods는 iOS 15 이상을 지원합니다.

### Swift Package Manager

```swift
.package(url: "https://github.com/Aiforpet-TTcare/AIScan.git", exact: "3.3.0")
```

앱 대상에 `AIScan` 제품을 추가하세요.

### CocoaPods

```ruby
pod 'AIScan',
    :git => 'https://github.com/Aiforpet-TTcare/AIScan.git',
    :tag => '3.3.0'
```

## 앱에서 검사 시작

앱의 번들 ID로 발급된 공개 키를 사용합니다. 프로젝트에 서버 분석이 활성화되어
있어야 합니다. 앱에서는 `AIScan` 모듈을 가져와 키를 설정한 뒤 카메라를 여세요.

```swift
import AIScan

AIScanManager.configure(publishableKey: publishableKey)

try AIScanManager.showCamera(
    petType: .dog,
    partType: .eye,
    on: viewController,
    petId: petID,
    allowsAlbum: true
) { result in
    switch result {
    case let .success(scan):
        handleScanResult(scan)
    case let .failure(error):
        handleScanError(error)
    }
}
```

결과 화면과 문진은 기본적으로 꺼져 있습니다. 필요한 경우 카메라를 열 때
`enableResultView: true`와 `enablesQuestionnaire: true`를 지정하세요. 다중 사진
모드에서는 앱이 결과 화면을 표시합니다.

## 선택적 동의와 원본 업로드

서버 배포가 완료되어 해당 앱에서 동의 옵션을 사용할 수 있게 된 후에만
`trainingConsent`와 `hospitalViewConsent`를 전달하세요. 두 옵션은 독립적인
`Bool?`입니다. `nil`이면 해당 항목을 생략하고, `true`와 `false`는 사용자
선택대로 전달합니다.

```swift
let camera = try AIScanManager.makeCameraViewController(
    petType: .dog,
    partType: .eye,
    petId: petID,
    userId: userID,
    trainingConsent: trainingChoice,
    hospitalViewConsent: hospitalViewChoice,
    allowsAlbum: true,
    enableMultiMode: true
)
```

`showCamera`와 `makeCameraViewController`의 두 콜백 형태에서 같은 옵션을
사용할 수 있습니다. 각 사진의 업로드와 분석에 해당 검사의 동의가 적용됩니다.
사용자 선택이 바뀌면 새 검사를 시작하세요.

서버에서 원본 업로드 식별자를 활성화한 연동은 비어 있지 않은 `petId`와
선택적 `userId`를 연동 규격에 맞춰 전달하세요. Core는 사진을 업로드할
때부터 분석할 때까지 같은 식별자를 사용합니다.

다중 사진 검사에서 기존 연동은 각 사진의 첫 분석 작업 전에 만료된
업로드를 자동으로 갱신합니다. Intopet 원본 업로드 식별자가 활성화된
연동에서 준비된 업로드가 만료되면 사용자가 사진을 다시 선택하거나
촬영해 새 업로드를 시작해야 합니다.

## 앨범 사진 검사

눈과 치아는 실시간 촬영과 단일·다중 앨범 검사에서 감지 영역의 긴 변을
허용 범위와 비교합니다. 크기는 자르거나 확대하기 전 원본 픽셀 기준이며,
최솟값과 설정된 최댓값을 포함합니다. 기본 최솟값은 270px, 치아의 기본
최댓값은 3000px입니다. 눈의 최댓값은 서버에서 지정한 경우 적용됩니다.
사진마다 감지된 눈·치아 위치가
유지되며, `analysisSubpart`를 지정하면 그 값이 우선합니다.

앨범 원본의 크기 제한은 사진당 24 MiB입니다. 원본 해상도와 색상 정보 요건은
[앨범 사진 검사 표](README.md#album-image-quality-315)에서 확인하세요.
앨범의 요구사항과 크기 안내는 한국어, 영어, 일본어, 이탈리아어, 스웨덴어,
태국어를 지원합니다.

## 콜백과 오류

서버 전용 콜백에는 문진 답변이 포함되지 않습니다. 서버가 연동 결과를
제공하면 `contractResult`로 받습니다. `enableMultiMode: true`에서는
선택 순서대로 사진별 성공과 실패를 받습니다. 기존 `(String?, Error?)`
콜백은 성공 시 JSON을 반환합니다. 실패 사유가 필요하면
`Result<AIScanResult, Error>` 콜백을 사용하세요.

Core 오류의 `NSError` 도메인과 코드를 함께 확인하세요. 실행 결과에 따라
`userInfo["reason"]`, HTTP 상태, 상세 원인과 해결 방법을 확인할 수 있습니다.
원본 업로드 식별자가 활성화된 검사에서 준비된 업로드가 만료되면
`upload_ticket_expired`(405)로 전달됩니다.

[변경 이력](CHANGELOG.md) · [전체 API 옵션과 결과 형식](README.md#configuration-options)
