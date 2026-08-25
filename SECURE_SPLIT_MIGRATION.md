# AIScan 3.0 Secure Split Migration

AIScan 3.0 separates the private Objective-C Core binary from the public Swift
UI while preserving the 2.2.4 camera and result design. This is the migration
guide for SDK integrators.

## High-Level Camera Entry Point

Configure the SDK once on the main actor with the publishable key issued for
the host application. Key validation, access-token minting, manifest transport,
analysis routing, and TTAPI communication remain inside `AIScanCore`.

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
| Device-attestation error `102` | Removed; key and organization policy are server-owned |

The old raw-result overloads cannot be compatibility aliases because restoring
them would reopen the protected inference boundary. The major version change
allows those APIs to be removed instead of leaking protected implementation
details back into the public source package.

## Partner contract result

When the organization manifest enables a partner contract, the completion
contains `AIScanResult.contractResult`. Its `schema` and JSON-compatible
`payload` are passed through without SDK-side renaming, calculation, filtering,
or supplementation. Existing non-partner integrations continue to use
`status`, `diagnosisID`, and `symptoms`.
