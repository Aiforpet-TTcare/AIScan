#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <AIScanCore/AISCConfiguration.h>
#import <AIScanCore/AISCDisplayResult.h>
#import <AIScanCore/AISCFrameEvaluation.h>
#import <AIScanCore/AISCScanTypes.h>
#import <AIScanCore/AISCSession.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AISCCameraEngineCompletion)(NSError *_Nullable error);
typedef void (^AISCCameraPermissionCompletion)(BOOL granted);

@protocol AISCCameraEngineDelegate <NSObject>

- (void)cameraEngineDidUpdateFrameState:(AISCFrameEvaluation *)evaluation;
- (void)cameraEngineDidAcceptCaptureState:(AISCFrameEvaluation *)evaluation;
@optional
/// Display-only image accepted by the private on-device preprocess chain.
/// It contains no private diagnostic implementation metadata.
- (void)cameraEngineDidAcceptPreviewImage:(CIImage *)previewImage;
/// Requests source UI presentation using display-safe prompts only. Model and
/// network work may continue while the user answers.
- (void)cameraEngineDidRequestQuestionnaire:(AISCQuestionnaire *)questionnaire;
@required
- (void)cameraEngineDidUpdateProgress:(double)normalizedProgress;
- (void)cameraEngineDidCompleteResult:(AISCDisplayResult *)result;
- (void)cameraEngineDidFail:(NSError *)error;

@end

/// Narrow UI-to-Core boundary. The binary owns AVCapture, scan transitions,
/// preprocess and diagnosis; source UI only renders approved events.
@protocol AISCCameraEngineControlling <NSObject>

@property (nonatomic, weak, nullable) id<AISCCameraEngineDelegate> delegate;
@property (nonatomic, assign) BOOL automaticallyCapturesReadyFrames;
@property (nonatomic, assign, readonly) AISCAnalysisMode analysisMode;
@property (nonatomic, strong, readonly) AVCaptureSession *captureSession;

- (void)prepareWithContext:(AISCScanContext *)context
                completion:(AISCCameraEngineCompletion)completion;
- (void)requestCameraAccess:(AISCCameraPermissionCompletion)completion NS_SWIFT_NAME(requestCameraAccess(completion:));
@optional
- (void)albumDidOpen NS_SWIFT_NAME(albumDidOpen());
- (void)albumDidCancel NS_SWIFT_NAME(albumDidCancel());
- (void)resultDidBecomeVisible NS_SWIFT_NAME(resultDidBecomeVisible());
- (void)resultDidShare NS_SWIFT_NAME(resultDidShare());
@required
- (void)prepareWithContext:(AISCScanContext *)context
                  progress:(nullable AISCPreparationProgress)progress
                completion:(AISCCameraEngineCompletion)completion;
- (void)prepareWithContext:(AISCScanContext *)context
          detailedProgress:(nullable AISCPreparationDetailedProgress)progress
                completion:(AISCCameraEngineCompletion)completion;
- (BOOL)configureCameraForPosition:(AVCaptureDevicePosition)position
                         disable4K:(BOOL)disable4K
                             error:(NSError **)error NS_SWIFT_NAME(configure(position:disable4K:));
- (void)startRunning;
- (void)stopRunning;
- (BOOL)setTorchEnabled:(BOOL)enabled error:(NSError **)error NS_SWIFT_NAME(setTorchEnabled(_:));
- (BOOL)setZoomFactor:(CGFloat)factor error:(NSError **)error NS_SWIFT_NAME(setZoomFactor(_:));
- (BOOL)scaleZoomBy:(CGFloat)scale error:(NSError **)error NS_SWIFT_NAME(scaleZoom(by:));
- (void)requestCapture;
@optional
- (void)beginCaptureAttempt NS_SWIFT_NAME(beginCaptureAttempt());
- (void)captureAttemptTimedOut NS_SWIFT_NAME(captureAttemptTimedOut());
@required
- (void)diagnosePhotoImage:(CIImage *)image NS_SWIFT_NAME(diagnosePhoto(_:));
- (void)diagnosePhotoInput:(AISCImageInput *)input NS_SWIFT_NAME(diagnosePhoto(_:));
- (void)submitQuestionnaireAnswers:(NSArray<AISCQuestionnaireAnswer *> *)answers
    NS_SWIFT_NAME(submitQuestionnaireAnswers(_:));
- (void)resetCaptureAttempt NS_SWIFT_NAME(resetCaptureAttempt());
- (void)reset;
- (void)cancel;

@end

@interface AISCCameraEngine : NSObject <AISCCameraEngineControlling>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfiguration:(AISCConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
