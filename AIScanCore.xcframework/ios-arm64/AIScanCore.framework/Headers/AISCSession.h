#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AIScanCore/AISCConfiguration.h>
#import <AIScanCore/AISCDisplayResult.h>
#import <AIScanCore/AISCError.h>
#import <AIScanCore/AISCFrameEvaluation.h>
#import <AIScanCore/AISCScanTypes.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AISCCompletion)(NSError *_Nullable error);
typedef void (^AISCFrameEvaluationCompletion)(AISCFrameEvaluation *_Nullable evaluation, NSError *_Nullable error);
typedef void (^AISCDisplayResultCompletion)(AISCDisplayResult *_Nullable result, NSError *_Nullable error);
typedef void (^AISCDiagnosisProgress)(double normalizedProgress);
typedef void (^AISCPreparationProgress)(double normalizedProgress);
typedef void (^AISCPreparationDetailedProgress)(double normalizedProgress,
                                                 int64_t bytesWritten,
                                                 int64_t totalBytes,
                                                 double bytesPerSecond);
typedef void (^AISCPhotoAccepted)(AISCImageInput *acceptedInput);

@interface AISCSession : NSObject

@property (nonatomic, assign, readonly) AISCAnalysisMode analysisMode;
@property (nonatomic, strong, readonly, nullable) AISCQuestionnaire *questionnaire;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfiguration:(AISCConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (void)prepareWithContext:(AISCScanContext *)context completion:(AISCCompletion)completion;
- (void)prepareWithContext:(AISCScanContext *)context
                  progress:(nullable AISCPreparationProgress)progress
                completion:(AISCCompletion)completion;
- (void)prepareWithContext:(AISCScanContext *)context
          detailedProgress:(nullable AISCPreparationDetailedProgress)progress
                completion:(AISCCompletion)completion;
- (void)evaluateFrame:(AISCFrameInput *)input completion:(AISCFrameEvaluationCompletion)completion;
- (void)captureFrame:(AISCFrameInput *)input completion:(AISCFrameEvaluationCompletion)completion;
- (void)diagnoseImage:(AISCImageInput *)input completion:(AISCDisplayResultCompletion)completion;
- (void)diagnoseImage:(AISCImageInput *)input
             progress:(nullable AISCDiagnosisProgress)progress
           completion:(AISCDisplayResultCompletion)completion;
- (void)diagnosePhoto:(AISCImageInput *)input
             accepted:(nullable AISCPhotoAccepted)accepted
             progress:(nullable AISCDiagnosisProgress)progress
           completion:(AISCDisplayResultCompletion)completion;
- (nullable AVCaptureDevice *)cameraDeviceForPosition:(AVCaptureDevicePosition)position NS_SWIFT_NAME(cameraDevice(for:));
- (CGFloat)cameraZoomFactorForRequestedFactor:(CGFloat)requestedFactor
                                       device:(AVCaptureDevice *)device NS_SWIFT_NAME(cameraZoomFactor(for:device:));
- (nullable AISCFrameInput *)frameInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                                device:(nullable AVCaptureDevice *)device NS_SWIFT_NAME(frameInput(for:device:));
- (nullable NSNumber *)cameraFrameMetricForPixelBuffer:(CVPixelBufferRef)pixelBuffer device:(AVCaptureDevice *)device NS_SWIFT_NAME(cameraFrameMetric(for:device:));
- (BOOL)applyCameraSessionPolicyToSession:(AVCaptureSession *)session
                                   device:(AVCaptureDevice *)device
                                disable4K:(BOOL)disable4K NS_SWIFT_NAME(applyCameraSessionPolicy(to:device:disable4K:));
- (void)applyCameraDevicePolicyToDevice:(AVCaptureDevice *)device enabled:(BOOL)enabled NS_SWIFT_NAME(applyCameraDevicePolicy(to:enabled:));
- (void)resetCameraDevicePolicy NS_SWIFT_NAME(resetCameraDevicePolicy());
- (void)cancel;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
