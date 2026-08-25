#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AIScanCore/AISCConfiguration.h>
#import <AIScanCore/AISCDisplayResult.h>
#import <AIScanCore/AISCFrameEvaluation.h>
#import <AIScanCore/AISCScanTypes.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AISCCameraEngineCompletion)(NSError *_Nullable error);

@protocol AISCCameraEngineDelegate <NSObject>

- (void)cameraEngineDidUpdateFrameState:(AISCFrameEvaluation *)evaluation;
- (void)cameraEngineDidAcceptCaptureState:(AISCFrameEvaluation *)evaluation;
- (void)cameraEngineDidUpdateProgress:(double)normalizedProgress;
- (void)cameraEngineDidCompleteResult:(AISCDisplayResult *)result;
- (void)cameraEngineDidFail:(NSError *)error;

@end

/// Narrow UI-to-Core boundary. The binary owns scan state transitions and the
/// selected analysis route; source UI supplies camera samples and renders only
/// approved evaluation/result events.
@protocol AISCCameraEngineControlling <NSObject>

@property (nonatomic, weak, nullable) id<AISCCameraEngineDelegate> delegate;
@property (nonatomic, assign) BOOL automaticallyCapturesReadyFrames;
@property (nonatomic, assign, readonly) AISCAnalysisMode analysisMode;

- (void)prepareWithContext:(AISCScanContext *)context
                completion:(AISCCameraEngineCompletion)completion;
- (void)consumeSampleBuffer:(CMSampleBufferRef)sampleBuffer
                     device:(nullable AVCaptureDevice *)device NS_SWIFT_NAME(consume(_:device:));
- (void)requestCapture;

- (nullable AVCaptureDevice *)cameraDeviceForPosition:(AVCaptureDevicePosition)position NS_SWIFT_NAME(cameraDevice(for:));
- (CGFloat)cameraZoomFactorForRequestedFactor:(CGFloat)requestedFactor
                                       device:(AVCaptureDevice *)device NS_SWIFT_NAME(cameraZoomFactor(for:device:));
- (BOOL)applyCameraSessionPolicyToSession:(AVCaptureSession *)session
                                   device:(AVCaptureDevice *)device
                                disable4K:(BOOL)disable4K NS_SWIFT_NAME(applyCameraSessionPolicy(to:device:disable4K:));
- (void)applyCameraDevicePolicyToDevice:(AVCaptureDevice *)device
                                enabled:(BOOL)enabled NS_SWIFT_NAME(applyCameraDevicePolicy(to:enabled:));
- (void)reset;
- (void)cancel;

@end

@interface AISCCameraEngine : NSObject <AISCCameraEngineControlling>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfiguration:(AISCConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
