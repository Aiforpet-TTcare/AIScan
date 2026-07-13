#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const AISCErrorDomain;
FOUNDATION_EXPORT NSErrorUserInfoKey const AISCDisplayReasonKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const AISCRetryableKey;
FOUNDATION_EXPORT NSErrorUserInfoKey const AISCHTTPublicStatusKey;

typedef NS_ENUM(NSInteger, AISCErrorCode) {
    AISCErrorCodeUnknown = 1,
    AISCErrorCodeInvalidConfiguration = 100,
    AISCErrorCodeUnauthorized = 101,
    AISCErrorCodeAttestationFailed = 102,
    AISCErrorCodeQuotaExceeded = 103,
    AISCErrorCodeNetworkUnavailable = 200,
    AISCErrorCodeRequestTimedOut = 201,
    AISCErrorCodeServerUnavailable = 202,
    AISCErrorCodeManifestUnavailable = 300,
    AISCErrorCodeManifestInvalid = 301,
    AISCErrorCodeModelUnavailable = 302,
    AISCErrorCodeModelIntegrityFailed = 303,
    AISCErrorCodeModelOpenFailed = 304,
    AISCErrorCodeInvalidInput = 400,
    AISCErrorCodeFrameRejected = 401,
    AISCErrorCodeUnsupportedPetPart = 402,
    AISCErrorCodeBusy = 403,
    AISCErrorCodeCancelled = 404,
    AISCErrorCodeInferenceFailed = 500,
    AISCErrorCodePostprocessFailed = 501,
    AISCErrorCodeUploadFailed = 502,
};

NS_ASSUME_NONNULL_END
