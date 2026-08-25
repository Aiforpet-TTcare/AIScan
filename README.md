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
    .package(url: "https://github.com/Aiforpet-TTcare/AIScan.git", from: "3.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

### CocoaPods

CocoaPods is retained only as a legacy compatibility channel. New integrations
should use Swift Package Manager; Pod validation and trunk publication do not
block the primary SDK release.

```ruby
pod 'AIScan', '~> 3.0.0'
```

### Secure Core / Reference UI

Swift Package Manager products:

```swift
.product(name: "AIScan", package: "AIScan")
.product(name: "AIScanCore", package: "AIScan")
.product(name: "AIScanCameraUI", package: "AIScan")
.product(name: "AIScanReferenceUI", package: "AIScan")
```

CocoaPods subspecs:

```ruby
pod 'AIScan/Core', '~> 3.0.0'
pod 'AIScan/CameraUI', '~> 3.0.0'
pod 'AIScan/ReferenceUI', '~> 3.0.0'
```

`AIScanCore` is the private Objective-C ABI binary for auth, manifest, model
execution, preprocessing, and TTAPI transport. `AIScanCameraUI` is public Swift
source and owns the original camera, guide, progress, and retry presentation.
See [ARCHITECTURE.md](ARCHITECTURE.md) and [RELEASE.md](RELEASE.md).

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
    publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx",
    environment: .test
)
```

## Usage

### Camera scan

```swift
try AIScanManager.showCamera(
    petType: .dog,
    partType: .eye,
    on: self
) { result in
    switch result {
    case let .success(scan):
        if let partnerResult = scan.contractResult {
            // Pass the contracted payload to the host app without remapping.
            print(partnerResult.payload)
        } else {
            print(scan.status)
        }
    case let .failure(error):
        print(error.localizedDescription)
    }
}
```

### Host-owned result view

```swift
let camera = try AIScanManager.makeCameraViewController(
    petType: .dog,
    partType: .eye,
    resultViewController: MyResultViewController()
)
present(camera, animated: true)
```

---

## Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `publishableKey` | `String` | *required* | Key issued for the host app. |
| `petType` | `PetType` | *required* | `.dog` or `.cat`. |
| `partType` | `PartType` | *required* | `.eye`, `.teeth`, `.body`, `.ear`, or `.paws`. |
| `analysisSubpart` | `String?` | `nil` | Contract analysis subpart, when required. |
| `analysisPosition` | `String?` | `nil` | Contract analysis position, when required. |
| `userId` | `String?` | `nil` | Host app user identifier. |
| `petId` | `String?` | `nil` | Host app pet identifier. |
| `recordId` | `String?` | `nil` | Host app record identifier. |
| `displayMetadata` | `[String: String]?` | `nil` | Display-safe metadata only. |

---

## Result Data

`AISCDisplayResult` intentionally exposes only display-safe fields.

| Field | Type | Description |
|---|---|---|
| `status` | `String` | Display status. |
| `diagnosisID` | `String?` | Server diagnosis identifier when available. |
| `symptoms` | `[AISCDisplaySymptom]` | Display-safe symptom rows. |
| `contractResult` | `AISCContractResult?` | Partner payload passed through without SDK remapping. |

`AISCDisplaySymptom` carries display names, levels, labels, and optional image
URLs. It does not expose model names, raw prediction values, thresholds, or
network schema fields.

---

## Error Handling

Core callbacks deliver `NSError` values from `AISCErrorDomain`.

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
