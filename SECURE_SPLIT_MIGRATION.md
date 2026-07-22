# Secure SDK Split Migration Draft

> Status: unreleased plan-branch draft. Do not use this document as release
> guidance until the secure split passes TDD77–TDD81 and a major-version policy
> is approved.

## High-Level Camera Entry Point

Configure the SDK once on the main actor with the publishable key issued for
the host application. Key validation, App Attest, access-token minting, and
manifest transport remain inside `AIScanCore`.

```swift
import AIScan

AIScanManager.configure(
    publishableKey: "tt_pk_test_xxxxxxxxxxxxxxxxxxxxxxxx"
)

try AIScanManager.showCamera(
    petType: .dog,
    partType: .eye,
    on: self,
    petId: "pet-id",
    userId: "user-id"
) { result in
    switch result {
    case let .success(scanResult):
        print(scanResult.status)
    case let .failure(error):
        print(error.localizedDescription)
    }
}
```

Hosts that own their presentation container can call
`makeCameraViewController(...)` and present the returned
`AIScanCameraViewController` themselves.

## Custom Result Controller

A host result controller receives only the display-safe result contract.

```swift
final class CustomResultViewController: UIViewController,
    AIScanResultViewControlling {
    func apply(result: AIScanResult) {
        // Render status, diagnosisID, and display-safe symptom rows.
    }
}

try AIScanManager.showCamera(
    petType: .dog,
    partType: .eye,
    on: self,
    resultViewController: CustomResultViewController()
)
```

`AIScanResult` contains only `status`, `diagnosisID`, and `[AIScanSymptom]`.
`AIScanSymptom` contains display names, display labels, abnormal level, and
optional crop/heatmap URLs. Model identifiers, raw predictions, tensors,
thresholds, local model paths, and transport payloads are not public.

## Intentional Migration Breaks

| Legacy 2.x behavior | Secure split behavior |
|---|---|
| License/auth-file configuration | `AIScanManager.configure(publishableKey:)` |
| SDK-owned top window | Host passes the presenting view controller with `on:` |
| Raw `AIScanResult`/diagnosis artifacts | Display-safe `AIScanResult` value |
| Result controller reads inference/model objects | `AIScanResultViewControlling.apply(result:)` |
| Host re-uploads generated ZIP/model artifacts | Not available |
| Global mutable scan options | Explicit context arguments or Core-owned policy |

The old raw-result overloads cannot be compatibility aliases because restoring
them would reopen the protected inference boundary. This requires an approved
major-version migration policy before release.

## Remaining Release Gates

- Signed-manifest envelope and verification-key rotation policy
- Short-lived content-key binding, expiry, refresh, and offline policy
- Real encrypted-model diagnosis/upload parity on a physical device
- Full camera/result UI, localization, accessibility, Dynamic Type, and paired
  light/dark screenshot approval
- Final private `develop` and public `main` synchronization and clean release
  provenance
