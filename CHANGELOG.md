# Changelog

## 3.0.16

- Explain album photo failures in everyday language, with a clear next step,
  across all six UI languages. Show this guidance before the quality measurements.
- Keep internal error numbers and untranslated provider reasons out of user-facing
  messages. Diagnostic errors and callback data remain available to host code.
- Preserve photo-inspection service errors so connection problems do not ask users
  to replace a valid photo. Offer a retry with the same selected photo.
- Keep the existing quality thresholds, original measurements, Core binaries and
  polygon callback payloads unchanged.

### Validation

- 198 public SDK tests passed, covering actionable failures, body-part-specific guidance,
  service-error preservation, same-photo retry and all six localization packs.
- Installed CocoaPods consumer tests, all seven guide animations, iOS 13
  compatibility and public distribution audits passed.
- Core binaries are unchanged from the verified 3.0.15 release.

## 3.0.15

- Preserve the SDK verdict when a TTAPI diagnosis ends as failed. Native quality
  rejections now reach the retry flow instead of becoming AISC-202 server errors.
- Give album users photo-selection guidance for resolution, color depth, subject
  size, blur and missing subjects. Name eyes, teeth or skin explicitly and use
  selected-photo wording across all six UI languages. Separate service/model retry guidance from
  photo-quality rejections, including PREPROCESS model failures.
- Report invalid HTTP requests as AISC-400, preserving the HTTP status. Provide
  localized messages for network, timeout, configuration, authorization, upload
  and analysis failures in all six UI languages.
- Preserve native and partner polygons across dictionary, string and Codable
  result surfaces. Existing callback payloads without polygons stay unchanged.

### Validation

- 85 Core tests and 192 public tests passed, including native quality failures,
  all 58 reference error classifications and exact polygon JSON preservation.
- CocoaPods consumer tests passed, including runtime playback of all seven
  guides. Device-target iOS 13 compatibility and public artifact audits passed.
- Nine follow-up copy tests passed, and localization keys match across Korean,
  English, Japanese, Italian, Swedish and Thai.
- Live host acceptance with a polygon-enabled project and physical-device
  acceptance for this version remain outstanding.

## 3.0.14

- Inspect album file metadata before image conversion. Display source width,
  height and bits per pixel; show failures in red with readable reasons.
- Require at least 1200×1200 pixels for skin, 900×900 for eyes and 1400×1400
  for teeth, with at least 24 source bits per pixel. Unavailable source metadata
  is rejected instead of treating decoded BGRA storage as original color depth.
- Measure eye/teeth subjects in upright original pixels before resizing. Both
  axes must reach 270 pixels for eyes or 400 pixels for teeth. TTAPI performs
  this detection-only check before upload; provider diagnosis remains unchanged.
- Keep analysis disabled while checking, discard obsolete photo checks, and
  scroll the quality panel on small displays. Add English, Korean and Japanese
  quality messages. Camera capture thresholds and final callback formats remain
  unchanged.

- Support Apple's PNG header prefix when reading source bit depth. Match the
  existing thread-safe Core completion adapters so CocoaPods Swift 6 consumers
  compile the album inspection path.

### Validation

- 190 public tests and 81 Core tests passed. Swift 6 CocoaPods validation passed.
- Actual local dog/cat eye and teeth images and a dog belly image completed
  TTAPI analysis with the existing direct payload contract. Three low-resolution
  images were rejected before analysis. Ear/paw images passed the new source
  checks and the provider requested retakes through the existing SDK mechanism.
- iOS 13 device-target compatibility and public artifact audits passed.
- The same 12-image acceptance run completed on a physical iPhone 17 Pro
  running iOS 26.6.2: five TTAPI successes, two provider retakes and three
  original-quality rejections, with no application errors. Installed CocoaPods
  consumer tests passed, including playback of all seven guides.

## 3.0.13

### Fixes

- Decide the outcome of a server diagnosis from `sdk_result.status` alone. A
  failed diagnosis (`ERROR`) is now reported as a non-retryable failure with no
  result — the original service answered the same case with HTTP 500 — instead
  of a successful result carrying the partner error DTO. `RETRY` drives the
  in-camera retake regardless of the partner payload, and a missing required
  contract is no longer offered for retry. The partner payload is never
  interpreted by the SDK. Core rebuilt from the 3.0.13 source.

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

### Validation

- 173 public tests passed on the reference iPhone 17 Pro / iOS 26.2 simulator.
- Static and dynamic CocoaPods consumers passed installed-resource checks,
  playback of all seven guide animations, and legacy completion checks.
- iOS 13 device-target compatibility build, CocoaPods lint, and release-tree,
  resource, privacy, public-header, and distribution audits passed.
- Physical-device acceptance in customer host apps remains outstanding.

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
