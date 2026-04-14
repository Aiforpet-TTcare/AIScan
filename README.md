# AIScan

### AI Health Diagnosis SDK for Dogs and Cats

---

**AIScan** is an AI-powered health diagnosis SDK for iOS that helps veterinarians and pet owners detect common health issues in dogs and cats through image analysis.

## Supported Diagnostics

| | Dog | Cat |
|---|:---:|:---:|
| **Eye** | ✅ | ✅ |
| **Teeth** | ✅ | ✅ |
| **Skin** (Ear / Body / Paws) | ✅ | ✅ |
| **Joint** | ✅ | - |

---

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Aiforpet-TTcare/AIScan.git", from: "1.3.7")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

### CocoaPods

```ruby
pod 'AIScan', '~> 1.3.7'
```

---

## Requirements

- iOS 13.0+
- Swift 5.9+
- Xcode 15+

---

## Setup

### 1. Configure Authentication

Place your authentication JSON file in the app bundle and initialize the SDK:

```swift
import AIScan

func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
    if let url = Bundle.main.url(forResource: "auth-config", withExtension: "json"),
       let data = try? Data(contentsOf: url) {
        TTManager.configure(authFileData: data)
    }
    return true
}
```

> **Important:** Do not expose the authentication file through app resource extraction methods.

### 2. (Optional) Analytics Tracker

```swift
TTManager.analysisTracker = YourAnalyticsTracker()  // conforms to TTAnalysisTracker
TTManager.isHapticEnabled = true
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

For skin diagnostics, enable the skin part selector so users can choose between Ear, Body, and Paws:

```swift
AIScanManager.showCamera(
    petType: .dog,
    partType: .belly,
    showSkinSelector: true,
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
        print("Status: \(result.abnormalStatus ?? "N/A")")
        print("Symptoms: \(result.abnormalSymptoms?.count ?? 0)")
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
| `partType` | `PartType` | *required* | `.eye`, `.tooth`, `.ear`, `.belly`, `.foot`, `.etc`, `.joint` |
| `petId` | `String?` | `nil` | Pet identifier |
| `userId` | `String?` | `nil` | User identifier |
| `recordId` | `String?` | `nil` | Record identifier |
| `petBirthday` | `String?` | `nil` | Pet birthday (e.g. `"2024-01-01"`) |
| `petBreedName` | `String?` | `nil` | Pet breed name |
| `petGender` | `String?` | `nil` | `"M"` or `"F"` |
| `guideUrl` | `String?` | `nil` | URL for camera guide page |
| `isFlashMode` | `Bool` | `true` | Enable flash mode |
| `enableResultView` | `Bool` | `true` | Show built-in result screen. Set `false` for data-only mode. |
| `showSkinSelector` | `Bool` | `false`/`true` | Show skin part selector popup. Default `true` for `resultCompletion` overload. |
| `enablesQuestionnaire` | `Bool?` | `nil` | Enable questionnaire. `nil` uses server config. |
| `allowsAlbum` | `Bool?` | `nil` | Show album button. `nil` uses server config. |
| `resultViewController` | `TTResultViewControllable?` | `nil` | Custom result view controller |

---

## Result Status

The SDK determines diagnosis status based on AI model analysis and optional questionnaire:

| Model | Questionnaire | Status | Meaning |
|:---:|:---:|:---:|---|
| Abnormal | Symptoms | **WARNING** | Seek veterinary care |
| Normal | Symptoms | **CAUTION** | Monitor closely (questionnaire-based) |
| Abnormal | No symptoms | **CAUTION** | Monitor closely (scan-based) |
| Normal | No symptoms | **NORMAL** | No concerning signs |

---

## Localization

AIScan supports the following languages:
- English (`en`)
- Korean (`ko`)
- Japanese (`ja`)

---

## License

**Data and API Subscription License**

This library requires a subscription license to access the AIScan service. Please refer to the service documentation for more details.

---

## Contact

For more information, visit [AI for Pet](https://www.aiforpet.com/)
