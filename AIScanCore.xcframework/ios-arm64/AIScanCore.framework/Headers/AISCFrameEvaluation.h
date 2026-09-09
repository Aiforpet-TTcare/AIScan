#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AISCScanState) {
    AISCScanStateIdle = 0,
    AISCScanStatePreparing = 1,
    AISCScanStateWarmingUp = 2,
    AISCScanStateTracking = 3,
    AISCScanStateStable = 4,
    AISCScanStateCaptureReady = 5,
    AISCScanStateCapturing = 6,
    AISCScanStateDiagnosing = 7,
    AISCScanStateCompleted = 8,
    AISCScanStateFailed = 9,
    AISCScanStateCancelled = 10,
};

typedef NS_ENUM(NSInteger, AISCGuidanceCode) {
    AISCGuidanceCodeNone = 0,
    AISCGuidanceCodeMoveCloser = 1,
    AISCGuidanceCodeMoveFarther = 2,
    AISCGuidanceCodeHoldStill = 3,
    AISCGuidanceCodeAdjustAngle = 4,
    AISCGuidanceCodeImproveLighting = 5,
    AISCGuidanceCodeAlignGuide = 6,
    AISCGuidanceCodeWait = 7,
};

typedef NS_ENUM(NSInteger, AISCCaptureDecision) {
    AISCCaptureDecisionReject = 0,
    AISCCaptureDecisionContinue = 1,
    AISCCaptureDecisionReady = 2,
    AISCCaptureDecisionCaptureNow = 3,
};

@interface AISCFrameEvaluation : NSObject

@property (nonatomic, assign, readonly) AISCScanState scanState;
@property (nonatomic, assign, readonly) AISCCaptureDecision captureDecision;
@property (nonatomic, assign, readonly) AISCGuidanceCode guidanceCode;
@property (nonatomic, assign, readonly) BOOL captureAllowed;
@property (nonatomic, assign, readonly) double normalizedProgress;
@property (nonatomic, copy, readonly, nullable) NSString *displayMessageKey;
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, NSString *> *overlayHints;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithScanState:(AISCScanState)scanState
                  captureDecision:(AISCCaptureDecision)captureDecision
                     guidanceCode:(AISCGuidanceCode)guidanceCode
                   captureAllowed:(BOOL)captureAllowed
               normalizedProgress:(double)normalizedProgress
                displayMessageKey:(nullable NSString *)displayMessageKey
                     overlayHints:(nullable NSDictionary<NSString *, NSString *> *)overlayHints NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
