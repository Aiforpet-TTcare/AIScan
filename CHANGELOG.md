# Changelog

## 3.2.0 (unreleased candidate)

- Disease analysis now runs exclusively through the server. Remove local disease
  inference, clinical post-processing, local heatmap generation and local-result
  record submission, including their diagnostic runtime.
- Keep camera/album classification, detection, blur and size checks on the device.
- Require explicit server-analysis authorization during preparation. Projects
  configured for local or mixed analysis must switch to server analysis before
  upgrading. Missing or unsupported routes fail before model downloads/uploads.
- Server errors no longer fall back to local disease analysis.
- Preserve public type names, historical route integers, result JSON, single/multi
  callback behavior, questionnaire display, result screens and PDF reports.
- Add localized project-configuration guidance in all six supported UI languages.

This is a review candidate; publication and live-provider photo acceptance are pending.


## 3.1.7

- Restore localized symptom names, explanations and result image URLs in the built-in single-photo result screen for native callback formats.
- Restore the complete analyzed catalog in PDF reports and distinguish unknown/unassessed findings from normal findings.
- Preserve native callback JSON and multi-photo collection, analysis and ordered array completion behavior.

## 3.1.6

- Multi-photo scans close the SDK camera before delivering their single ordered result-array callback. The host app owns the multi-photo result UI.
- In multi mode, ignore `enableResultView`, `resultViewController`, and `enablePdfShare`. Single-photo result screens and callback behavior are unchanged.

## 3.1.5

- Validate the selected animal and body part before accepting album photos. Eye/teeth detection alone no longer bypasses the animal classifier, and dog-skin photos also require content inspection.
- Apply existing pet/part crop-blur models and configured confidence thresholds to album inspection. Block single-photo analysis and automatic multi-photo registration on quality rejection or inspection failure, with localized guidance and existing retry recovery.
- Preserve source resolution, 24-bit color-depth and 270px eye/teeth longest-side requirements, upright original images for analysis, and the direct multi-result JSON array introduced in 3.1.4.
- Place photo-review scroll indicators in the outer margin while retaining photo sizes and 20pt content spacing.
- Correct two English teeth instructions and cover album classification/blur guidance across all six UI languages.

**Scope:** the existing dog-skin classifier does not distinguish ear/belly/foot. These remain user-selected positions. No new model or callback schema is introduced.

## 3.1.4

- Match Android multi-photo callbacks: each array item is the direct photo result, without an SDK-added photoId/photoIndex/result wrapper. Preserve provider fields, URLs and polygons.
- Keep failure and retake entries in selection order, using status/error/reasonCode/message directly on the array item. Return exactly one callback after every photo finishes.
- Retain typed Swift photoResults metadata and read previously stored wrapped arrays/aggregate objects. Single-photo callbacks remain unchanged.

**Multi-mode migration from 3.1.3:** read each array item directly instead of its result property. Array order identifies the selected photos.

## 3.1.3

- Deliver multi-photo callback JSON as the ordered root array; single-photo callbacks remain unchanged. Swift hosts can use `jsonArray` or typed `photoResults`.
- Display actual completed-photo count while rotating progress previews, so the counter does not cycle with the shown photo.
- Show inline activity and prevent conflicting album actions during loading and inspection, while keeping close available and ignoring late results.
- Start original-photo loading before dismissing its system picker, close the list immediately, and wait for dismissal before inspection or review. Show an available preview while loading and recover controls when loading or inspection times out.
- Move multi-photo review to a grid control beside the shutter, show it only after collecting a photo, and return every photo slot and back action directly to camera.
- Add validated album photos directly to multi-photo review; retain the explicit analysis button for single-photo album scans.
- Restore the album preview frame's screen-adaptive height while preserving centered fill cropping.
- Reduce the centered camera eye guide to two thirds of its previous size.

**Multi-mode migration:** parse the callback root as an array instead of reading
the former object's `results` property. The typed Swift completion still returns
`AIScanResult`; use `jsonArray` or `photoResults`. Multi mode remains opt-in and
defaults to `false`. Single-photo callbacks, Core binaries, quality criteria and
each photo's nested provider payload remain unchanged.

## 3.1.2

- Match album and multi-photo review to the dark camera style, with a pinned album action and separate camera/album controls.

- Expose the accepted-camera-photo callback to Objective-C Core so multi-photo captures open review instead of an invalid-input popup.
- Verify the actual optional-selector dispatch boundary and delivery of the accepted image to the UI.


## 3.1.1

- Fill the fixed diagnosis-progress photo frame with a centered crop for every image ratio.
- Apply terminal multi-photo progress immediately before returning the aggregate callback.


## 3.1.0

- Add optional `enableMultiMode` (default `false`) for one to four camera/album photos.
- Upload each accepted original during review; start TTAPI analyses concurrently only after confirmation.
- Return successes, retakes and failures together once in photo order, with unchanged nested result JSON and polygons.
- Add a themed photo review grid, rotating progress previews and an optional result summary with per-photo PDF export.
- Keep existing single-photo behavior and all six UI languages.


## 3.0.21

- Accept album eye and tooth detections when their longer side is at least
  270 original-image pixels. Reduce the tooth detection minimum from 400 to 270
  and stop requiring both detection dimensions to meet the minimum.
- Preserve source-image resolution/bit-depth checks, detection failures, original
  images for analysis, fixed center-cropped previews, Core binaries and callbacks.

## 3.0.20

- Preserve at least 16 points of horizontal padding on retake buttons in every
  UI language. Let longer translations expand the button instead of touching
  its rounded edges.

- Keep the album preview frame the same size when changing photos. Fill the frame
  using the photo’s display aspect ratio and center-crop overflow.
- Bound the frame to 380 points and adapt it to shorter viewports. Preserve the
  full original image for analysis and the border attached to the frame.
- Keep quality checks, user guidance, Core binaries and callback data unchanged.

## 3.0.19

- Keep the album border attached to the photo card itself so it resizes with the
  preview immediately when changing photos. Remove the separate shape path that
  could retain the preceding photo’s size.
- Preserve photo aspect-ratio sizing, maximum-height cropping, full originals for
  analysis, quality checks and Core binaries.

## 3.0.18

- Size the album preview from the selected photo’s display aspect ratio, including
  EXIF rotation. Landscape and square photos no longer share a fixed-height frame.
- Limit preview height to 380 points and 60% of the viewport on small screens.
  Crop overflow inside the preview; preserve the full original for analysis.
- Keep quality checks, localized guidance, Core binaries and callback data unchanged.

## 3.0.17

- Remove original-photo dimensions, detected-area dimensions and bit-depth values
  from the album screen. Retain the internal quality gates and measurements.
- Show only localized photo-checking status and actionable guidance, including
  the existing same-photo retry for service failures. Polygon callbacks and
  Core binaries are unchanged.

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
