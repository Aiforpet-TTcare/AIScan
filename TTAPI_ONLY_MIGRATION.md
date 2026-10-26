# Server-only disease analysis (3.2.0)

Version 3.2.0 removes local disease analysis.

## Before upgrading

Ask your project administrator to enable server analysis for the application's
project and confirm that it is available for the registered app and key. Test
and Live credentials retain their existing permissions and environments.
A locally configured or mixed-analysis project is not automatically converted.
If server analysis is unavailable, initialization of a scan ends with a localized
configuration error before any model download or photo upload. Correct the project
configuration and start a fresh scan. The SDK does not bypass server authorization.

An internet connection is required for disease analysis. Upload, service and
analysis errors use the existing error/retry handling; they cannot trigger a
local diagnosis. A previously installed 3.x SDK continues to use its pinned code.

## What stays the same

Continue to integrate the single AIScan product and use AIScanManager.configure
and the existing camera methods. Camera/album classification, eye and tooth
measurement, blur checks, guidance and multi-photo collection remain on the device.
Dog eye, tooth, ear, belly and foot calls and cat eye/tooth calls are unchanged.

The single-photo callback, ordered direct multi-photo array, typed results,
server-provided payload and image URLs retain their established contracts.
Historical OnDevice* result types and route integers remain available for source
compatibility and reading previously saved responses; they do not enable local
analysis. Multi-photo scans still return one final callback and do not open a
built-in multi-result screen. Single-photo result/PDF options are unchanged.

## Consumer verification

Before shipping your host app, verify its actual registered Test and Live project
configuration, single and multi-photo success, invalid image retry, service failure,
network timeout/cancel, background/foreground camera resume, result image loading
and PDF export. Pin version 3.2.0 after verifying your registered project configuration.
