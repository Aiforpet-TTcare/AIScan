# Samsung Fire TTAPI Validation Host

This branch-only app loads the local public `AIScan` Swift package directly. It
does not use CocoaPods or the legacy private Example app.

Generate the project after editing `project.yml`:

```sh
rtk xcodegen generate --spec Examples/SecureSplitValidationHost/project.yml
```

Open `Examples/SecureSplitValidationHost/SecureSplitValidationHost.xcodeproj`,
select the connected iPhone, and set the Samsung Test publishable key from
Secret Manager (`samsung-fire-ttapi-test-publishable-key`) as the
`AISCAN_PUBLISHABLE_KEY` scheme environment variable. Never commit or print the
real key. The app defaults to Test; switch to Live only with a Live key.

For physical-device screenshot tests, keep the phone unlocked with Developer
Mode and UI Automation enabled. If Xcode reports `Timed out while enabling
automation mode`, enable UI Automation in the device's Developer settings and
rerun the UI test scheme; a normal signed build/install/launch does not require
that automation session.

The host provides:

- one button for every currently supported Samsung TTAPI target: DOG/CAT eye
  left/right, DOG skin ear/belly/foot, and DOG/CAT tooth center/left/right;
- exact `EYEL`/`EYER`, `TCENTER`/`TLEFT`/`TRIGHT`, and lowercase skin position
  values in both ticket and diagnosis-job requests;
- a host-owned entry point into the fixed-dark public camera;
- system, light, and dark appearance controls;
- a deterministic sample result with the three eye symptom tabs;
- a simulator-safe camera error/retry screenshot path with display-safe errors;
- UI tests that retain light/dark result screenshots in the result bundle.

The host main bundle explicitly declares English, Korean, and Japanese. A
consumer app must declare every language it supports so iOS can select the
corresponding localization inside the SDK resource bundles.

Device sign-off must record camera permission, live preview, retry, capture and
result transitions, real original/analysis images, English/Japanese layouts,
and comparison against the released 2.2.4 app. Verify that the completion is a
pass-through `contractResult.payload` matching `ttcare.anomaly-check.v1` and
record the displayed end-to-end duration. Simulator screenshots alone do not
complete TDD80.
