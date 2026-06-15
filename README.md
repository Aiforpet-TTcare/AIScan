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
| **Joint** | ✅ | - |

---

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Aiforpet-TTcare/AIScan.git", from: "2.1.9")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

### CocoaPods

```ruby
pod 'AIScan', '~> 2.1.9'
```

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

| Key prefix | Use | App Attest |
|---|---|---|
| `tt_pk_test_…` | Development / testing | Not required (works in the simulator) |
| `tt_pk_live_…` | Production | **Required** — iOS 14+ on a real device |

> The publishable key is safe to ship in the app binary. It only mints
> short-lived access tokens at runtime; it cannot be used to read or modify
> account data.

---

## Setup

Register the platform client **once** at app launch (e.g. in your `AppDelegate`
or scene setup). App identity (bundle ID, app version) is read automatically from
`Bundle.main`, so the bundle ID must match the app registered for your key.

```swift
import AIScan

func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
    do {
        let client = try AIScanClient(
            publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx"  // provided by AI for Pet
        )
        AIScanClientBridge.register(client)
    } catch {
        print("AIScan init failed: \(error)")
    }
    return true
}
```

`AIScanClientBridge.register(_:)` wires the SDK to the AI for Pet platform —
all subsequent scans route their token / manifest / upload / record calls
through this client.

> **Important**
> - Register **once** per process, before the first `showCamera` call. Re-registering
>   is unnecessary and should be avoided.
> - `AIScanClient(...)` throws `Error.invalidPublishableKey` if the key is malformed
>   (must start with `tt_pk_`). Handle it rather than force-trying.
> - Call **`showCamera` on the main thread.** It asserts main-thread execution and
>   will crash otherwise.

### (Optional) Analytics & Haptics

```swift
AIScanManager.analysisTracker = YourAnalyticsTracker()  // conforms to TTAnalysisTracker
AIScanManager.isHapticEnabled = true
```

---

## Usage

### Basic — Camera with Built-in Result View

```swift
AIScanManager.showCamera(
    petType: .dog,
    partType: .eye,
    petBirthday: "2024-01-01",
    petGender: "F"
) { diagnosisId, error in
    if let error {
        print("Error: \(error)")
        return
    }
    print("Diagnosis ID: \(diagnosisId ?? "nil")")
}
```

### Skin Part Selector

For skin diagnostics, pass `partType: .skin` to let users choose between
Ear, Body, and Paws:

```swift
AIScanManager.showCamera(
    petType: .dog,
    partType: .skin,
    resultCompletion: { result, error in
        // result: AIScanResult?
    }
)
```

### Full Result Data (AIScanResult)

Use `resultCompletion` instead of `completion` to receive the full structured result:

```swift
AIScanManager.showCamera(
    petType: .cat,
    partType: .eye,
    resultCompletion: { result, error in
        guard let result else { return }
        print("Status: \(result.response?.status ?? "N/A")")
        print("Symptoms: \(result.response?.symptoms?.count ?? 0)")
    }
)
```

### Data-Only Mode (No Result View)

Skip the built-in result screen and receive data directly via the completion callback:

```swift
AIScanManager.showCamera(
    petType: .dog,
    partType: .eye,
    enableResultView: false
) { diagnosisId, error in
    // Camera closes automatically after diagnosis.
    // Build your own result UI with the returned data.
}
```

### Custom Result View

Provide your own result view controller:

```swift
let customResultVC = MyResultViewController()  // conforms to TTResultViewControllable

AIScanManager.showCamera(
    petType: .dog,
    partType: .tooth,
    resultViewController: customResultVC
) { diagnosisId, error in
    // ...
}
```

---

## Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `petType` | `PetType` | *required* | `.dog` or `.cat` |
| `partType` | `PartType` | *required* | `.eye`, `.tooth`, `.ear`, `.belly`, `.foot`, `.skin`, `.joint` |
| `petId` | `String?` | `nil` | Pet identifier |
| `userId` | `String?` | `nil` | User identifier |
| `recordId` | `String?` | `nil` | Record identifier |
| `petName` | `String?` | `nil` | Pet name |
| `petBirthday` | `String?` | `nil` | Pet birthday (e.g. `"2024-01-01"`) |
| `petBreedName` | `String?` | `nil` | Pet breed name |
| `petGender` | `String?` | `nil` | `"M"` or `"F"` |
| `petAdditionalInfo` | `String?` | `nil` | Free-form caller metadata |
| `guideUrl` | `String?` | `nil` | URL for camera guide page |
| `isFlashMode` | `Bool` | `true` | Enable flash mode |
| `allowsAlbum` | `Bool?` | `nil` | Show album button. `nil` uses server config. |
| `enableResultView` | `Bool` | `true` | Show built-in result screen. Set `false` for data-only mode. |
| `enablesQuestionnaire` | `Bool?` | `nil` | Enable questionnaire. `nil` uses server config. |
| `enablePdfShare` | `Bool?` | `nil` | Enable PDF report share. `nil` uses server config. |
| `resultViewController` | `TTResultViewControllable?` | `nil` | Custom result view controller |

> Pass `partType: .skin` (not `.belly`/`.foot`/`.ear`) to surface the in-app skin
> part selector. The selected sub-part is reported back in the result.

---

## Result Status

The SDK determines diagnosis status from the AI model analysis and the optional questionnaire:

| Model | Questionnaire | Status | Meaning |
|:---:|:---:|:---:|---|
| Abnormal | Symptoms | **WARNING** | Seek veterinary care |
| Normal | Symptoms | **CAUTION** | Monitor closely (questionnaire-based) |
| Abnormal | No symptoms | **CAUTION** | Monitor closely (scan-based) |
| Normal | No symptoms | **NORMAL** | No concerning signs |

---

## Result Data Schema

When you use `resultCompletion`, the closure receives an `AIScanResult`. Diagnosis
runs on-device, so the result is assembled locally — there is no server round-trip
for the result payload itself.

### `AIScanResult`

| Field | Type | Description |
|---|---|---|
| `response` | `OnDeviceResponse?` | Full structured result — status, symptoms, images, descriptions |
| `questions` | `[OnDeviceQuestion]?` | Questionnaire answers, when the questionnaire ran |
| `position` | `String?` | Scanned sub-part (`"EYER"`, `"EYEL"`, `"BELLY"`, `"FOOT"`, `"EAR"`, …) |
| `createdAt` | `Int?` | Result time (Unix milliseconds) |
| `metadata` | `[String: AnyCodable]?` | Whatever you passed via `petAdditionalInfo` |

> The overall status and the symptom list live on `response` (`response.status`,
> `response.symptoms`) — read them from there.

### `OnDeviceResponse`

| Field | Type | Description |
|---|---|---|
| `title` | `String?` | Headline message for the result status |
| `analyzedDate` | `String?` | Display date, formatted `"yyyy. MM. dd HH:mm"` |
| `status` | `String?` | `"NORMAL"` / `"ABNORMAL"` (questionnaire + scan combined) |
| `description` | `OnDeviceDescription?` | `time_to_see_a_vet` or `home_care_tips` block |
| `symptoms` | `[OnDeviceSymptom]?` | One entry per detected condition |
| `cropImageUrl` | `String?` | Representative crop image URL |
| `heatmapPath` | `String?` | Representative heatmap image URL |

### `OnDeviceSymptom`

| Field | Type | Description |
|---|---|---|
| `code` | `String?` | Catalog code (e.g. `redness`, `epiphora`, `calculus`) |
| `name` | `String?` | Localized display name |
| `modelName` | `String?` | Originating model key |
| `isAbnormal` | `Bool?` | Whether this condition is flagged abnormal |
| `abnormLevel` | `Int?` | Severity (`0` normal, `1` abnormal) |
| `resultLabel` | `String?` | Raw class label |
| `score` | `Double?` | Inference confidence, `0...1` |
| `cropImageUrl` | `String?` | Per-symptom crop image URL |
| `heatmapPath` | `String?` | Per-symptom heatmap image URL |
| `details` | `[OnDeviceSymptomDetail]?` | Explanatory sections (what it is, causes, what to do) |

> The symptom list is keyed by the symptom catalog and de-duplicated: when more than
> one model maps to the same condition, you receive a single merged entry (the
> abnormal result takes precedence). Expect at most one entry per condition code.

### Result Image URLs

`cropImageUrl` / `heatmapPath` resolve in one of two ways:

- **Uploaded (typical):** a public `https://cdn-results.ai4pet.com/…` URL — durable,
  safe to display or forward to your own backend.
- **Local fallback:** a `file://…` path inside the SDK's working directory, used only
  if the upload for that image failed. These are **valid for the current session
  only** and may be cleaned up afterward — copy the bytes out if you need to keep them.

Both kinds may appear in the same result; check the scheme before persisting.

### Sample Result (JSON)

iOS delivers the result as an `AIScanResult` object. The JSON below is its
equivalent shape — the same payload a host can forward to a mother app, aligned
with the Android SDK output. Keys map 1:1 to the struct fields; `nil` fields are
omitted. (Example: a dog skin scan with one abnormal symptom.)

```json
{
  "subPart": "BELLY",
  "userId": "user-123",
  "createdAt": 1749800000000,
  "response": {
    "title": "Monitor Closely",
    "analyzedDate": "2026. 06. 15 14:30",
    "status": "ABNORMAL",
    "description": {
      "title": "Home Care Tips",
      "contents": ["Keep the area clean and dry.", "Watch for changes over the next few days."]
    },
    "cropImageUrl": "https://cdn-results.ai4pet.com/app_…/upl_…/diagnosis_crop",
    "heatmapPath": "https://cdn-results.ai4pet.com/app_…/upl_…/diagnosis_heatmap",
    "symptoms": [
      {
        "code": "redness",
        "name": "Redness",
        "modelName": "redness",
        "isAbnormal": true,
        "abnormLevel": 1,
        "resultLabel": "abnormal",
        "score": 0.87,
        "cropImageUrl": "https://cdn-results.ai4pet.com/app_…/upl_…/diagnosis_crop",
        "heatmapPath": "https://cdn-results.ai4pet.com/app_…/upl_…/diagnosis_heatmap",
        "details": [
          { "key": "what_it_is", "title": "What it is", "contents": ["…"] },
          { "key": "what_you_can_do", "title": "What you can do", "contents": ["…"] }
        ]
      }
    ]
  },
  "questions": [
    { "text": "Is your pet scratching the area?", "select": "yes" }
  ]
}
```

> `symptoms` includes every analyzed model (normal entries carry `isAbnormal: false`
> / `abnormLevel: 0`), de-duplicated per condition code. For a NORMAL result the
> array still carries the analyzed conditions, and the representative
> `cropImageUrl` / `heatmapPath` are populated from the scan.

---

## Error Handling

The completion / result closures deliver an `Error` for failures the host should
surface. When the built-in result view is enabled, the SDK also shows the user a
localized alert and reports a short diagnostic code.

| Code prefix | Meaning | User-facing guidance |
|---|---|---|
| `Dxxx` | Out of local storage | Free up space and retry |
| `Ixxx` / `Exxx` | Transient on-device error (inference/engine) | Temporary error — retry |
| `Pxxx` | Result upload failed | Check the network connection |
| `Txxx` / `Jxxx` | Token mint / server-response parsing failed | Retry |
| `Cxxx` | Diagnosis quota exhausted | No remaining scans on the plan |
| others | Connectivity | Check the internet connection |

Notes:

- Codes are stable, single-letter-prefixed strings (e.g. `P001`, `T002`, `C001`).
  Branch on the **prefix**, not the full string.
- `Txxx` errors mean the publishable key could not mint an access token — verify the
  key, the app's bundle ID matches the registered app, and (for `tt_pk_live_…` keys)
  that you are on a real device with App Attest available.

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
