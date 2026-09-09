#if SWIFT_PACKAGE
// The UI is intentionally public source. Re-exporting its API keeps consumer
// integration at `import AIScan` while the Objective-C Core stays hidden.
@_spi(AIScanLifecycle) @_spi(AIScanValidation) @_exported import AIScanCameraUI
@_exported import AIScanReferenceUI
#endif

/// Public module marker.
public enum AIScanSDK {}
