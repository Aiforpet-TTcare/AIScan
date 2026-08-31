# AIScan iOS 2.2.4 -> 3.x migration guide

This guide migrates an application from the iOS SDK currently documented at
<https://sdk.aiforpet.com/> (v2.2.4) to the secure-split 3.x SDK. Use the exact
3.x version announced in the release notice; do not use an unannounced branch
or prerelease tag.

## What changes

| Area | v2.2.4 | 3.x |
| --- | --- | --- |
| Minimum OS | iOS 15 | iOS 13 |
| Distribution | SPM-wrapped Swift XCFramework; CocoaPods supported | SPM primary; CocoaPods compatibility only |
| Initialization | `AIScanClient` + `AIScanClientBridge.register` | `AIScanManager.configure(publishableKey:)` |
| Presentation | SDK entry point owns presentation | Host passes the presenter with `on:` |
| Completion | `(String?, Error?)` or typed legacy callback | `Result<AIScanResult, Error>` |
| On-device result | Legacy `response`, `questions`, and identity fields | Same customer-facing fields retained |
| Partner result | Not part of the normal 2.2.4 path | Optional `contractResult`, delivered without remapping |
| Protected logic | Swift binary and runtime dependencies | Objective-C ABI Core binary; Swift UI remains source-compatible |
| Attestation | The old site describes App Attest for live keys | No SDK App Attest integration; server policy owns authorization |

The camera, guide, questionnaire, retry, progress, result, and PDF interfaces
remain visually and functionally equivalent to the 2.2.4 baseline. The public
entry point changes because protected authentication, manifest, preprocessing,
model, and TTAPI logic now live behind `AIScanCore`.

## 1. Pin and install the announced version

Keep a copy of the existing `Package.resolved` or `Podfile.lock` so rollback is
one version change. For Swift Package Manager, remove any sample-app package
and add only the official repository:

```swift
dependencies: [
    .package(
        url: "https://github.com/Aiforpet-TTcare/AIScan.git",
        exact: "<ANNOUNCED_3_X_VERSION>"
    )
]
```

Add the `AIScan` product to the application target. Consumer applications must
not add `AIScanCore`, `AIScanCameraUI`, or `AIScanReferenceUI` as separate
products.

For CocoaPods compatibility:

```ruby
target 'YourTargetName' do
  pod 'AIScan', '<ANNOUNCED_3_X_VERSION>'
end
```

After changing the version, reset package caches and resolve packages again,
or run `pod update AIScan --repo-update`, then clean DerivedData.

## 2. Replace initialization

Remove the old bridge registration:

```swift
// Remove in 3.x.
let client = try AIScanClient(publishableKey: publishableKey)
AIScanClientBridge.register(client)
```

Configure the facade once, before the first scan:

```swift
import AIScan

@MainActor
func configureAIScan() {
    AIScanManager.configure(publishableKey: publishableKey)
}
```

`import AIScan` is the only import required by a host application. Omit the
environment argument in normal integrations. Test and Live routing is selected
by the issued key and its server-side project registration.

Do not restore the removed auth JSON, client secret, team-ID override, bundle-ID
override, or App Attest code in the host app.

## 3. Replace the camera call

The presenting view controller is now explicit, the method can throw before
presentation, and the completion uses Swift `Result`:

```swift
import AIScan

@MainActor
func startEyeScan(from viewController: UIViewController) {
    do {
        try AIScanManager.showCamera(
            petType: .dog,
            partType: .eye,
            on: viewController,
            petId: "PET_ID",
            petName: "Coco",
            petBreedName: "Maltese",
            petBirthday: "2023-12-13",
            petGender: "F",
            userId: "USER_ID",
            recordId: "HOST_RECORD_ID",
            enablesQuestionnaire: true,
            allowsAlbum: true,
            enableResultView: true,
            enablePdfShare: true
        ) { result in
            switch result {
            case let .success(scan):
                handle(scan)
            case let .failure(error):
                handle(error)
            }
        }
    } catch {
        handle(error)
    }
}
```

Call all UI entry points on the main actor. Applications that own a custom
container may use `makeCameraViewController(...)` and present the returned view
controller themselves.

### Part names

Use the actual 3.x cases below. Names such as `.teeth`, `.body`, and `.paws`
that appeared in an early 3.0 README are not public `PartType` cases.

| Scan | 3.x value | Notes |
| --- | --- | --- |
| Eye | `.eye` | Dog and cat; side is detected automatically |
| Tooth | `.tooth` | Dog and cat; position is detected automatically |
| Skin selector | `.skin` | Dog; SDK asks the user to select a skin area |
| Ear | `.ear` | Dog; use only when the host already chose the area |
| Body | `.belly` | Dog; use only when the host already chose the area |
| Paw | `.foot` | Dog; use only when the host already chose the area |

`analysisSubpart` and `analysisPosition` are optional provider context. Do not
invent values for normal eye or tooth scans. The SDK supplies the correct
position when it detects or collects one.

## 4. Handle the two result shapes

The completion always returns `AIScanResult`. Its content depends on the
server-selected analysis and response contract.

```swift
func handle(_ result: AIScanResult) {
    if let contract = result.contractResult {
        // Partner contract: pass the direct JSON-compatible payload unchanged.
        sendPartnerPayload(contract)
        return
    }

    // Ordinary on-device result: legacy customer-facing fields are retained.
    let status = result.response?.status
    let symptoms = result.response?.symptoms ?? []
    let questions = result.questions ?? []
    renderOnDevice(status: status, symptoms: symptoms, questions: questions)
}
```

Ordinary on-device results retain `petType`, `part`, `createdAt`, `questions`,
`response`, `userId`, `petId`, and `subPart`. `response.symptoms` is the complete
customer-facing catalog. Use `isAbnormal`, `abnormLevel`, `resultLabel`, and
`response.status` for presentation; raw model predictions and thresholds are
not public.

`result.string` and `result.jsonString` remain available when an existing host
must forward JSON, but new Swift integrations should use typed fields.

### Result and questionnaire switches are independent

- `contractResult` is delivered through completion whenever the server supplies
  it.
- `enableResultView` controls only the SDK's built-in result screen and defaults
  to `false`.
- `enablesQuestionnaire` controls only questionnaire presentation and defaults
  to `false`.
- `allowsAlbum` controls only the photo-library entry and defaults to `false`.
- A host's debug/JSON popup is an app-level option. Show it only when the built-in
  result view is disabled so two result surfaces do not overlap.
- The SDK built-in result screen does not reinterpret a partner payload.

## 5. Error and cancellation handling

`showCamera` can throw `AIScanManagerError.notConfigured` before presentation.
The completion returns `.failure` for a terminal error or user cancellation.
Retryable capture and TTAPI image-quality failures remain inside the camera flow
and use the SDK retry UI; they must not be converted into a second host callback.

Do not branch on the old single-letter v2.2.4 error prefixes. Log the NSError
domain/code for support, display the SDK-provided localized message, and keep
server/network details out of user-visible copy.

## 6. Migration test matrix

Before changing a Live key, run all of the following with a Test key on a real
device:

1. Dog eye, dog tooth, dog skin, cat eye, and cat tooth complete once.
2. Camera and album inputs both reach a terminal result.
3. Skin `.skin` opens the area selector; direct `.ear`, `.belly`, and `.foot`
   start in the selected area.
4. Questionnaire on/off, built-in result on/off, and PDF on/off are independent.
5. A normal on-device key returns no `contractResult` and preserves the legacy
   result JSON.
6. A contract-enabled key returns `contractResult` exactly once without changing
   the ordinary result behavior of other organizations.
7. Camera permission denial opens Settings; guide close resumes the camera.
8. iOS 13, the oldest supported device OS, and the current iOS release both pass.

## 7. Rollout and rollback

Pin the exact release. Roll out to an internal Test app, then a small Live
canary, then all customers. Monitor prepare failures, retry rate, terminal
latency, crash-free scans, and callback count by SDK version and analysis mode.

Rollback by pinning the previous exact SDK tag and restoring the saved lockfile.
Do not reuse or move an existing tag.

## Release note for SDK maintainers

The 3.x public tag must be produced from the one-commit clean release staging
flow described in `RELEASE.md`. A private development branch or its history is
not a distributable artifact.
