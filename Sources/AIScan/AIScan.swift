#if SWIFT_PACKAGE
@_exported import AIScanCore
@_exported import AIScanCameraUI
@_exported import AIScanReferenceUI
#else
// CocoaPods compiles the overlay and both UI source folders into the AIScan
// pod module, so only the binary Core is a separate module there.
@_exported import AIScanCore
#endif
