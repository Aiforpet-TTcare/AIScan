# Secure Split Validation Host

This branch-only app loads the local public `AIScan` Swift package directly. It
does not use CocoaPods or the legacy private Example app.

Generate the project after editing `project.yml`:

```sh
rtk xcodegen generate --spec Examples/SecureSplitValidationHost/project.yml
```

Open `Examples/SecureSplitValidationHost/SecureSplitValidationHost.xcodeproj`,
select the connected iPhone, and set the `AISCAN_PUBLISHABLE_KEY` scheme
environment variable. Never commit a real key. Choose the matching environment
inside the app before presenting the camera.

The host provides:

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
and comparison against the released 2.2.4 app. Simulator screenshots alone do
not complete TDD80.
