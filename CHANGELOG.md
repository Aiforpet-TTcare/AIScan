# Changelog

## 3.0.13

### Added

- Restore the original `(String?, Error?)` completion on `showCamera` and
  `makeCameraViewController` for hosts that branch only on a `nil` result, as
  1.x/2.x integrations do. `result` is the direct partner payload JSON
  (`AIScanResult.jsonString`) when a scan completes and `nil` when the flow ends
  without one — including a failed diagnosis, which the original service
  answered with HTTP 500 and the gateway now returns as an `ERROR` contract
  payload — and `error` is always `nil` exactly as 1.x/2.x delivered it;
  retake stays inside the camera. The `Result<AIScanResult, Error>` completion
  is unchanged and remains the way to observe the failure reason.

## 3.0.12

### Fixes

- Include all seven capture-guide animations in CocoaPods resource bundles and
  resolve packaged resources for both CocoaPods and Swift Package Manager.
- Skip missing or unreadable guide animations without terminating the app or
  leaving capture waiting indefinitely; complete a finite guide only once.
- Resume eligible live camera flows after temporary full-screen presentation,
  preserve the retry capture restart introduced in 3.0.10, and correct the initial
  popup position without repeating its entrance animation.
- Calculate the on-device questionnaire fallback against the remaining scan
  deadline after uploads, so slow uploads do not incorrectly extend the wait.
- Restore the 3.0.9 public environment configuration and partner result contract:
  dictionary access and direct payload JSON, including ordinary on-device result
  fields.

### Compatibility

`contractResult` is `[String: Any]?` again. Integrations that used the
`AIScanContractResult?` wrapper property in 3.0.10/3.0.11 must use
`typedContractResult` for schema/payload access. Structured construction accepts
a nonoptional `AIScanContractResult`; legacy dictionary and explicit `nil`
construction remain available. Partner JSON contains the direct payload, without
an SDK-added wrapper.

Create a fresh camera controller through the public factory for each new scan
after completion or cancellation. See the [migration guide](SECURE_SPLIT_MIGRATION.md)
for examples and host-app acceptance checks.

This patch corrects existing behavior; it does not introduce new network features
or change the partner payload schema. Host-app acceptance testing remains necessary
for integration-specific repeated-capture behavior.

### Validation

- 167 public simulator tests and 76 Core simulator tests passed.
- Static and dynamic CocoaPods consumers each passed installed-resource,
  actual guide-playback, and legacy result-contract checks.
- Device build, iOS 13 compatibility, resource, privacy, and distribution-boundary
  checks passed.
- Exact visual comparisons retain the original iOS 26.2 references and use separate
  verified iOS 18.5 references for system separator colors and the share symbol.
