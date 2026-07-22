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
    .package(url: "https://github.com/Aiforpet-TTcare/AIScan.git", from: "2.2.4")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

### CocoaPods

```ruby
pod 'AIScan', '~> 2.2.4'
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
pod 'AIScan/Core', '~> 2.2.4'
pod 'AIScan/CameraUI', '~> 2.2.4'
pod 'AIScan/ReferenceUI', '~> 2.2.4'
```

`AIScanCore` is the Objective-C binary facade. `AIScanCameraUI` owns the
AVFoundation session, preview, torch, zoom, and frame delivery. `AIScanReferenceUI`
renders display-safe result DTOs.

---

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+

---

## Authentication

AIScan authenticates with a **publishable key** that AI for Pet issues for your app.
Contact us to receive your key — we generate and provide it together with the app
registration (bundle ID) it is bound to.

| Key prefix | Use | App Attest |
|---|---|---|
| `tt_pk_test_…` | Development / testing | Not required (works in the simulator) |
| `tt_pk_live_…` | Production | **Required** — iOS 14+ on a real device |

> The publishable key is safe to ship in the app binary. It only mints
> short-lived access tokens at runtime; it cannot be used to read or modify
> account data.

---

## Setup

Create an `AISCConfiguration` with the publishable key and keep one
`AISCSession` for the scan flow.

```swift
import AIScanCore

let configuration = AISCConfiguration(
    publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx"
)
let session = AISCSession(configuration: configuration)
```

## Usage

### Basic — Core Session

```swift
let context = AISCScanContext()
context.petType = .dog
context.partType = .eye

session.prepare(with: context) { error in
    if let error { print("Prepare failed: \(error)") }
}
```

### Frame Evaluation

```swift
guard let frameInput = session.frameInput(for: sampleBuffer, device: device) else { return }

session.evaluateFrame(frameInput) { evaluation, error in
    if let error {
        print("Frame rejected: \(error)")
        return
    }
    print("Ready to capture: \(evaluation?.captureAllowed == true)")
}
```

### Diagnosis Result

```swift
let imageInput = AISCImageInput(pixelBuffer: pixelBuffer)

session.diagnoseImage(imageInput) { result, error in
    if let error {
        print("Diagnosis failed: \(error)")
        return
    }
    guard let result else { return }
    print("Status: \(result.status)")
}
```

### Reference Result View

```swift
import AIScanReferenceUI

AIScanResultReferenceView(result: result)
```

The default view restores the production camera/result structure while keeping
all inference policy inside `AIScanCore`. Hosts with approved display copy can
build a richer result without exposing scores or model data:

```swift
let section = AIScanDisplayDetailSection(
    id: "description",
    kind: .symptomDescription,
    title: "What is this sign?",
    lines: ["Display-safe explanatory copy"]
)

let viewModel = AIScanDisplayResultViewModel(
    status: "CAUTION",
    symptoms: [
        AIScanDisplaySymptomViewModel(
            code: "display-code",
            name: "Display name",
            detailSections: [section]
        )
    ],
    statusStyle: .caution,
    createdAtText: "2026. 07. 22 11:45"
)

AIScanResultReferenceView(viewModel: viewModel)
```

`AIScanDisplayDetailSection` is presentation-only. Do not place thresholds,
raw predictions, model identifiers, or transport payloads in it.

---

## Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `publishableKey` | `String` | *required* | Key issued for the host app. |
| `petType` | `AISCPetType` | *required* | `.dog` or `.cat`. |
| `partType` | `AISCPartType` | *required* | `.eye`, `.teeth`, `.skin`, or `.joint`. |
| `displaySubpart` | `String?` | `nil` | Display-safe selected subpart text. |
| `userIdentifier` | `String?` | `nil` | Host app user identifier. |
| `petIdentifier` | `String?` | `nil` | Host app pet identifier. |
| `recordIdentifier` | `String?` | `nil` | Host app record identifier. |
| `displayMetadata` | `[String: String]?` | `nil` | Display-safe metadata only. |

---

## Result Data

`AISCDisplayResult` intentionally exposes only display-safe fields.

| Field | Type | Description |
|---|---|---|
| `status` | `String` | Display status. |
| `diagnosisID` | `String?` | Server diagnosis identifier when available. |
| `symptoms` | `[AISCDisplaySymptom]` | Display-safe symptom rows. |

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
