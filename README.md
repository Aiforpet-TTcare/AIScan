# AIScan

### AI Health Diagnosis SDK for Dogs and Cats

---

**AIScan** is an AI-powered health diagnosis SDK for iOS that helps veterinarians and pet owners detect common health issues in dogs and cats through on-device image analysis.

## Supported Diagnostics

| | Dog | Cat |
|---|:---:|:---:|
| **Eye** | ✅ | ✅ |
| **Teeth** | ✅ | ✅ |
| **Skin** (Ear / Body / Paws) | ✅ | - |

---

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Aiforpet-TTcare/AIScan.git", exact: "3.0.13")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

### CocoaPods

CocoaPods remains a compatibility channel. New integrations should use Swift
Package Manager. Both installation paths must include the SDK's guide resources.

```ruby
pod 'AIScan',
    :git => 'https://github.com/Aiforpet-TTcare/AIScan.git',
    :tag => '3.0.13'
```

### Single public module

Swift Package Manager product:

```swift
.product(name: "AIScan", package: "AIScan")
```

Consumer code uses only `import AIScan`. The public Swift UI surface is available
through that facade; the Objective-C Core is neither a separate product nor
re-exported.
See [ARCHITECTURE.md](ARCHITECTURE.md), [migration guidance](SECURE_SPLIT_MIGRATION.md),
[CHANGELOG.md](CHANGELOG.md), and [RELEASE.md](RELEASE.md). Use a version only after
its release tag is published; examples on a release branch describe the candidate.

---

## Requirements

- iOS 13.0+
- Swift 5.9+
- Xcode 15+

---

## Authentication

AIScan authenticates with a **publishable key** that AI for Pet issues for your app.
Contact us to receive your key — we generate and provide it together with the app
registration (bundle ID) it is bound to.

| Key prefix | Use |
|---|---|
| `tt_pk_test_…` | Development / testing |
| `tt_pk_live_…` | Production |

Organization policy, including key-only contracted access, is resolved by the
server-side manifest and remains Core-owned.

> The publishable key is safe to ship in the app binary. It only mints
> short-lived access tokens at runtime; it cannot be used to read or modify
> account data.

---

## Setup

Configure the SDK once with the publishable key.

```swift
import AIScan

AIScanManager.configure(
    publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx"
)
```

The publishable key identifies the registered Test or Live app. The single-argument
configuration uses the production service. Existing integrations can explicitly
select the service environment with
`AIScanManager.configure(publishableKey: key, environment: .production)` or
`.development`; use the environment specified for your integration.

## Usage

### Camera scan

```swift
try AIScanManager.showCamera(
    petType: .dog,
    partType: .eye,
    on: self,
    petName: "Bori",
    petBreedName: "Maltese",
    enableResultView: true,
    enablePdfShare: true
) { result in
    switch result {
    case let .success(scan):
        if let partnerResult = scan.contractResult {
            // Pass the contracted payload to the host app without remapping.
            print(partnerResult)
        } else {
            print(scan.status)
        }
    case let .failure(error):
        print(error.localizedDescription)
    }
}
```

Hosts written against the 1.x/2.x `(String?, Error?)` completion can keep that
closure unchanged. `result` is the direct partner payload JSON when a scan
completes and `nil` otherwise — including a failed diagnosis, which the
original service answered with HTTP 500 and the gateway now returns as an
`ERROR` contract payload. `error` is always `nil`, exactly as in 1.x/2.x.
Retake is handled inside the camera and never reaches the host. Use the
`Result` completion above when the failure reason or the error DTO matters.

```swift
try AIScanManager.showCamera(petType: .dog, partType: .eye, on: self) { result, error in
    guard let result else {
        // Cancelled or failed; `error` is nil as in 1.x/2.x.
        return
    }
    deliver(resultJSON: result)
}
```

### Host-owned result view

```swift
let camera = try AIScanManager.makeCameraViewController(
    petType: .dog,
    partType: .eye,
    enableResultView: true,
    resultViewController: MyResultViewController()
)
present(camera, animated: true)
```

### Repeated scans

Call `showCamera(...)` or `makeCameraViewController(...)` for each new scan.
Present a fresh controller after the previous scan has closed; do not cache and
re-present a completed or cancelled controller. The SDK's in-flow retry action
starts another capture attempt without requiring a new controller.

A temporary full-screen presentation can pause the live camera. On return, the
SDK resumes an eligible camera flow without restarting a closed, completed,
cancelled, or diagnosing scan. Missing or unreadable guide animation resources
are skipped so they do not terminate the app or permanently block capture.

---

## Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `publishableKey` | `String` | *required* | Key issued for the host app. |
| `petType` | `PetType` | *required* | `.dog` or `.cat`. |
| `partType` | `PartType` | *required* | `.eye`, `.tooth`, `.skin`, `.ear`, `.belly`, or `.foot`. |
| `analysisSubpart` | `String?` | `nil` | Contract analysis subpart, when required. |
| `analysisPosition` | `String?` | `nil` | Contract analysis position, when required. |
| `userId` | `String?` | `nil` | Host app user identifier. |
| `petId` | `String?` | `nil` | Host app pet identifier. |
| `petName` | `String?` | `nil` | Name printed on the optional screening report. |
| `petBreedName` | `String?` | `nil` | Breed printed on the report cover. |
| `petBirthday` | `String?` | `nil` | Birthday printed on the report cover. |
| `petGender` | `String?` | `nil` | Gender printed on the report cover. |
| `recordId` | `String?` | `nil` | Host app record identifier. |
| `displayMetadata` | `[String: String]?` | `nil` | Display-safe metadata only. |
| `enablesQuestionnaire` | `Bool` | `false` | Presents the SDK questionnaire when enabled. |
| `allowsAlbum` | `Bool` | `false` | Shows the photo-library entry when enabled. |
| `enableResultView` | `Bool` | `false` | Presents the built-in result UI when explicitly enabled, independently of whether `contractResult` is also delivered. The default receives only the completion callback. |
| `enablePdfShare` | `Bool` | `true` | Shows the original result-footer action, generates the A4 report, then opens the system share sheet. |

### Privacy manifest

AIScan ships privacy manifests for both the public Swift UI resources and every
Core XCFramework slice. The SDK declares no tracking. For app functionality it
may transmit the selected/captured pet image, a host-supplied user identifier,
and host-supplied scan content such as pet, record, and questionnaire values.
Host apps remain responsible for matching their App Store privacy answers and
privacy notice to the identifiers and optional metadata they choose to provide.

`AIScanManager.onPDFExported` receives the protected local PDF URL on the main
actor before the share sheet opens. `AIScanManager.lastExportedPDFURL` retains
the most recently generated URL for the current process.

---

## Result Data

`AIScanResult` intentionally exposes only callback-safe fields.

| Field | Type | Description |
|---|---|---|
| `status` | `String` | Display status. |
| `diagnosisID` | `String?` | Server diagnosis identifier when available. |
| `symptoms` | `[AIScanSymptom]` | Display-safe symptom rows. |
| `contractResult` | `[String: Any]?` | Original partner payload dictionary, compatible with 3.0.9. |
| `typedContractResult` | `AIScanContractResult?` | Opt-in schema and payload view when schema metadata is available. |

`AIScanSymptom` carries display names, levels, labels, and optional image
URLs. It does not expose model names, raw prediction values, thresholds, or
network schema fields.

`contractResult` is always forwarded through the completion callback when the
server supplies one. Its presence does not control questionnaire presentation
or `enableResultView`; hosts that show partner JSON should do so with a separate
app-level option.

For partner results, `string`, `jsonString`, and `JSONEncoder` output the payload
directly, without adding a `schema`/`payload` envelope. Ordinary on-device results
retain the legacy `petType`, `part`, `createdAt`, `questions`, `response`, `userId`,
`petId`, and `subPart` fields.

If your 3.0.10/3.0.11 integration accesses `contractResult.schema` or
`contractResult.payload`, change those accesses to `typedContractResult`. The
`contractResult` property is a dictionary again in 3.0.12. See the
[3.0.12 upgrade notes](SECURE_SPLIT_MIGRATION.md#upgrading-from-309-3010-or-3011)
for typed construction and serialization details.

---

## Error Handling

Failures are delivered as `Error`; use `localizedDescription` for display and
cast to `NSError` only when the host needs the stable numeric code.

| Code prefix | Meaning | User-facing guidance |
|---|---|---|
| `100...` | Invalid configuration or input | Check the scan context or frame input. |
| `200...` | Engine state | Retry after prepare, or wait for the active operation. |
| `300...` | Manifest or remote setup | Check network and key registration. |

---

## Localization

AIScan supports the following languages:
- English (`en`)
- Korean (`ko`)
- Japanese (`ja`)

The SDK follows the host app's locale.

---

## License

**Data and API Subscription License**

This library requires a subscription license to access the AIScan service.
Please refer to the service documentation for more details.

---

## Contact

For your publishable key or any other questions, visit [AI for Pet](https://www.aiforpet.com/).
